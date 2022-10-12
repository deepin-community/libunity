#!/usr/bin/env python2

import os, sys
import subprocess
import re

"""
# This script has two modes of operation:
#
# 1) Capture a trace and generate a html visualization.
#    To use this mode just run `./capture_trace.py`. This will setup a lttng
#    session, enable all userspace trace events and spawns a subshell where
#    you can for example run libunity-tool to perform a search on a scope.
#    When the subshell exits, tracing is stopped and visualization is generated.
#
# 2) Only generate a html visualization of a previously captured trace.
#    Use `./capture_trace.py /path/to/lttng/trace_dir`.
#
# Note that use use the first mode you need to have lttng installed
# and libunity compiled with --enable-lttng option.
# Required packages (besides requirements for libunity's --enable-lttng):
# sudo apt-get install lttng-tools babeltrace
"""

"""
# --- Manually capturing a trace
# lttng create session_name
# lttng enable-event -u -a
# lttng start
# --- start home scope with lttng-enabled branch of libunity, perform a search
# lttng stop
# lttng destroy
# --- view the trace in cli
# babeltrace ~/lttng_traces/<session_name dir>
"""
def capture_lttng_trace():
    session = subprocess.check_output(["lttng", "create", "libunity-trace"], stdin=subprocess.PIPE)
    trace_started = False
    try:
        subprocess.check_output(["lttng", "enable-event", "-u", "-a"], stdin=subprocess.PIPE)
        subprocess.check_output(["lttng", "start"], stdin=subprocess.PIPE)
        trace_started = True
        sys.stderr.write("Trace running... Close this sub-shell with Ctrl+D to finish\n")
        subprocess.check_call(["bash"]) # let this inherit our stdin
    except subprocess.CalledProcessError as cpe:
        if trace_started:
            # bash will return non-zero exit code if you for example Ctrl+C
            # a program within it, let's just ignore those errors
            msg = "Warning: subshell returned error: " + str(cpe.returncode)
            sys.stderr.write(msg + "\n")
        else: raise
    finally:
        if trace_started:
            subprocess.check_output(["lttng", "stop"], stdin=subprocess.PIPE)
        subprocess.check_output(["lttng", "destroy", "libunity-trace"], stdin=subprocess.PIPE)

    match = re.findall(r'Traces will be written in (.+)', session)
    if len(match) > 0: return match[0]
    return None

# trace event example
"""
[20:00:30.697493680] (+0.000014138) miso-ThinkPad:unity-scope-hom:26439 libunity:message: { cpu_id = 0 }, { message = "flush::com.canonical.Unity.Master.Scope.home.T296521243842038" }
"""

def parse_trace_line(line):
    pattern = re.compile(r'^\[(?P<timestamp>[0-9:\.]+)\].+?{ message = "(?P<msg>[^"]+)"')
    match = pattern.match(line)
    timestamp = match.group("timestamp")
    msg = match.group("msg")
    msg_parts = msg.split("::", 2)
    if len(msg_parts) > 1:
        msg_type = msg_parts[0]
        msg = {}
        for kv in msg_parts[1].split(";"):
            items = kv.split("=", 2)
            if len(items) > 1:
                msg[items[0]] = items[1]
            else:
                msg['content'] = items[0]
    else:
        msg_type = "other"
        msg = {'content': msg}

    return (timestamp, msg_type, msg)

def find_end_event(events, searched_event, event_type):
    for i in range(len(events)):
        event = events[i]
        if event[1] == event_type and event[2] == searched_event[2]:
            return i
    return -1

def pair_events(events):
    paired = []
    i = 0
    while i < len(events):
        event = events[i]
        event_type = event[1]
        if event_type.endswith(":start"):
            group = event[1].split(":", 2)[0]
            j = find_end_event(events[i+1:], event, group + ":end")
            if j >= 0:
                end_event = events.pop(i+j+1)
                paired.append((event, end_event))
                i = i+1
                continue
        paired.append((event, None))
        i = i+1

    return paired

COLOR_FOR_EVENT = {
    'search': "'#394a6b'",
    'subsearch': "'#109618'",
    'changeset': "'#990099'",
    'diff': "'#e57357'",
    'flush': "'#ff9900'",
    'push': "'#0099c6'"
}

def produce_html(trace_name, pairs):
    base = """<html><head><title>%s</title></head><body>
<script type="text/javascript" src="https://www.google.com/jsapi?autoload={'modules':[{'name':'visualization',
       'version':'1','packages':['timeline']}]}"></script>
<script type="text/javascript">

google.setOnLoadCallback(drawChart);
function drawChart() {
  var dataTable = new google.visualization.DataTable();

  dataTable.addColumn({ type: 'string', id: 'group' });
  dataTable.addColumn({ type: 'string', id: 'id' });
  dataTable.addColumn({ type: 'string', id: 'data' });
  dataTable.addColumn({ type: 'datetime', id: 'Start' });
  dataTable.addColumn({ type: 'datetime', id: 'End' });

  dataTable.addRows([
    %s
  ]);

  var view = new google.visualization.DataView(dataTable);
  view.setColumns([0,1,3,4]);

  var container = document.getElementById('example2.1');
  var chart = new google.visualization.Timeline(container);

  chart.draw(view);
}
</script>

<div id="example2.1" style="height: 100%%;"></div>
</body></html>"""
    rows = []
    colors = []
    for pair in pairs:
        (start_event, end_event) = pair
        (timestamp, event_type, metadata) = start_event
        has_end_ts = end_event is not None

        group = event_type if not event_type.endswith(":start") else event_type.split(":", 2)[0]
        color = COLOR_FOR_EVENT[group] if group in COLOR_FOR_EVENT else "'#c60000'"
        has_scope_id = 'scope' in metadata
        scope_id = metadata['scope'] if has_scope_id else metadata['content']
        if has_scope_id: del metadata['scope']
        else:
            if group in ['changeset', 'flush', 'diff']:
                match = re.match(r'com.canonical.Unity\.Master\.Scope\.(\w+)\.T', scope_id)
                if match: scope_id = "%s.scope" % match.group(1)
        data = str(metadata).replace("'", "\\'")

        # we're loosing our lovely nanosecond precision :(
        map_to_int = lambda x: int(x[0:3])
        start_date = map(map_to_int, re.findall(r'\d+', timestamp))
        end_date = start_date
        if has_end_ts:
            end_date = map(map_to_int, re.findall(r'\d+', end_event[0]))

        event_name = "%s - %s" % (group, metadata['target']) if 'target' in metadata else group
        data_tuple = (scope_id, group, data, ",".join(map(str,start_date)), ",".join(map(str, end_date)))
        data_format = "[ '%s', '%s', '%s', new Date(0,0,0,%s), new Date(0,0,0,%s) ]"
        data_row = data_format % data_tuple
        rows.append(data_row)
        colors.append(color)
    return base % ("Analysis of %s" % trace_name, ",\n".join(rows))

def get_events_from_babeltrace(trace_dir):
    events = []
    all_events = subprocess.check_output(["babeltrace", trace_dir])
    lines = filter(None, all_events.split("\n"))
    for line in lines:
        event = parse_trace_line(line)
        events.append(event)
    return events

def main(args):
    output_name = None
    if len(args) > 1:
        trace_dir = args[1]
    else:
        trace_dir = capture_lttng_trace()

    if trace_dir:
        basename = os.path.basename(trace_dir)
        if not basename:
            basename = os.path.basename(os.path.dirname(trace_dir))
        output_name = "%s.html" % basename

    events = get_events_from_babeltrace(trace_dir)
    if len(events) == 0:
        raise RuntimeError("There are 0 events in the trace")
    pairs = pair_events(events)
    html = produce_html(trace_dir, pairs)

    if output_name:
        sys.stderr.write("Writing output to '%s'\n" % output_name)
        f = open(output_name, 'w')
        f.write(html)
        f.close()
    else:
        print html

if __name__ == "__main__":
    main (sys.argv)

