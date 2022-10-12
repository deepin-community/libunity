using Unity;



int main(string[] args)
{
	int i = 0;
	var loop = new MainLoop();
	MusicPlayer test_player = null;

	Idle.add_full (Priority.HIGH, () => {
		const string desktop_file_name = "rhythmbox.desktop";
		test_player = new MusicPlayer(desktop_file_name);
		test_player.export();
		
		return false;	
	});

	Idle.add_full (Priority.LOW, () => {
		set_blacklisted(test_player);
		if (++i < 100)
			return true;
		test_player.unexport();
		loop.quit();
		return false;
	});

	loop.run();
	
	return 0;
}

void set_blacklisted(MusicPlayer test_player)
{
	int raw_blacklist = Random.int_range(0, 2);
	bool blacklist = (bool) raw_blacklist;	
	test_player.is_blacklisted = blacklist;
}