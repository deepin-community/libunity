#! /usr/bin/python2

from gi.repository import GObject, GLib, Dee, Unity

class Merger (GObject.Object, Unity.MergeStrategy):
	def __init__ (self):
		GObject.Object.__init__ (self)
	
	def do_merge_result (self, model, row, n_cols):
		print "MERGE", model, row, n_cols
		return model.append_row (row)

m = Merger()
l = Unity.Lens.new ("/test/lens", "testlens")
s = Unity.Scope.new ("/test/scope")
l.props.merge_strategy = m
l.add_local_scope (s)

# For the sake of the example try and add some stuff to the model
# directly. Nroamlly this'd be in response to s search...
s.props.results_model.append ("uri1", "icon", 0, "mimetype", "display-name", "comment", "dnd-uri")
s.props.results_model.append ("uri2", "icon", 0, "mimetype", "display-name", "comment", "dnd-uri")
s.props.results_model.append ("uri3", "icon", 0, "mimetype", "display-name", "comment", "dnd-uri")



  
