//	This file is part of FeedReader.
//
//	FeedReader is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	FeedReader is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with FeedReader.  If not, see <http://www.gnu.org/licenses/>.

using GLib;
using Gtk;

namespace FeedReader {

	public const string QUICKLIST_ABOUT_STOCK = N_("About FeedReader");

	dbUI dataBase;
	GLib.Settings settings_general;
	GLib.Settings settings_state;
	GLib.Settings settings_tweaks;
	GLib.Settings settings_keybindings;
	Logger logger;


	public class FeedApp : Gtk.Application {

		private readerUI m_window;
		public signal void callback(string content);

		protected override void startup()
		{
			logger = new Logger("ui");

			logger.print(LogMessage.INFO, "FeedReader " + AboutInfo.version);
			dataBase = new dbUI();


			dataBase.init();
			base.startup();

			if(GLib.Environment.get_variable("XDG_CURRENT_DESKTOP").down() == "gnome")
			{
				var quit_action = new SimpleAction("quit", null);
				quit_action.activate.connect(this.quit);
				this.add_action(quit_action);

				this.app_menu = UtilsUI.getMenu();
			}
		}

		public override void activate()
		{
			base.activate();

			WebKit.WebContext.get_default().set_web_extensions_directory(Constants.InstallPrefix + "/share/FeedReader/");

			if(m_window == null)
			{
				m_window = new readerUI(this);
				m_window.set_icon_name("feedreader");
				if(settings_tweaks.get_boolean("sync-on-startup"))
					sync.begin((obj, res) => {
						sync.end(res);
					});
			}

			m_window.show_all();

			try
			{
				DBusConnection.connectSignals(m_window);
				DBusConnection.get_default().updateBadge();
				DBusConnection.get_default().checkOnlineAsync();
			}
			catch(GLib.Error e)
			{
				logger.print(LogMessage.ERROR, "FeedReader.activate: %s".printf(e.message));
			}
		}

		public override int command_line(ApplicationCommandLine command_line)
		{
			var args = command_line.get_arguments();
			if(args.length > 1)
			{
				logger.print(LogMessage.DEBUG, "FeedReader: callback %s".printf(args[1]));
				callback(args[1]);
			}

			activate();

			return 0;
		}

		protected override void shutdown()
		{
			try
			{
				logger.print(LogMessage.DEBUG, "Shutdown!");
				if(settings_tweaks.get_boolean("quit-daemon"))
					DBusConnection.get_default().quit();
				base.shutdown();
			}
			catch(GLib.Error e)
			{
				logger.print(LogMessage.ERROR, "FeedReader.shutdown: %s".printf(e.message));
			}
		}

		public async void sync()
		{
			SourceFunc callback = sync.callback;
			ThreadFunc<void*> run = () => {
				try
				{
					DBusConnection.get_default().startSync();
				}
				catch(IOError e)
				{
					logger.print(LogMessage.ERROR, e.message);
				}
				Idle.add((owned) callback);
				return null;
			};

			new GLib.Thread<void*>("sync", run);
			yield;
		}

		public readerUI getWindow()
		{
			return m_window;
		}

		public FeedApp()
		{
			GLib.Object(application_id: "org.gnome.FeedReader", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
		}
	}


	public static int main (string[] args) {

		settings_general = new GLib.Settings("org.gnome.feedreader");
		settings_state = new GLib.Settings("org.gnome.feedreader.saved-state");
		settings_tweaks = new GLib.Settings("org.gnome.feedreader.tweaks");
		settings_keybindings = new GLib.Settings("org.gnome.feedreader.keybindings");

		try {
			var opt_context = new OptionContext();
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);
		} catch (OptionError e) {
			print(e.message + "\n");
			return 0;
		}

		if(version)
		{
			stdout.printf("Version: %s\n", AboutInfo.version);
			stdout.printf("Git Commit: %s\n", Constants.g_GIT_SHA1);
			return 0;
		}

		if(about)
		{
			show_about(args);
			return 0;
		}

		if(media != null)
		{
			UtilsUI.playMedia(args, media);
			return 0;
		}

		if(pingURL != null)
		{
			logger = new Logger("ui");
			Utils.ping(pingURL);
			return 0;
		}

		if(test)
		{
			UtilsUI.testGOA();
			return 0;
		}

		Gst.init(ref args);
		var app = new FeedApp();
		app.run(args);

		return 0;
	}

	private const GLib.OptionEntry[] options = {
		{ "version", 0, 0, OptionArg.NONE, ref version, "FeedReader version number", null },
		{ "about", 0, 0, OptionArg.NONE, ref about, "spawn about dialog", null },
		{ "playMedia", 0, 0, OptionArg.STRING, ref media, "start media player with URL", "URL" },
		{ "ping", 0, 0, OptionArg.STRING, ref pingURL, "test the ping function with given URL", "URL" },
		{ "test", 0, 0, OptionArg.NONE, ref test, "test", null },
		{ null }
	};

	private static bool version = false;
	private static bool about = false;
	private static string? media = null;
	private static string? pingURL = null;
	private static bool test = false;

	static void show_about(string[] args)
	{
		Gtk.init(ref args);
        Gtk.AboutDialog dialog = new Gtk.AboutDialog();
        dialog.response.connect ((response_id) => {
			if(response_id == Gtk.ResponseType.CANCEL || response_id == Gtk.ResponseType.DELETE_EVENT)
				Gtk.main_quit();
		});

		dialog.artists = AboutInfo.artists;
		dialog.authors = AboutInfo.authors;
		dialog.documenters = null;
		//dialog.translator_credits = AboutInfo.translators;

		dialog.program_name = AboutInfo.programmName;
		//dialog.comments = AboutInfo.comments;
		dialog.copyright = AboutInfo.copyright;
		dialog.version = AboutInfo.version;
		dialog.logo_icon_name = AboutInfo.iconName;
		dialog.license_type = Gtk.License.GPL_3_0;
		dialog.wrap_license = true;

		dialog.website = AboutInfo.website;
		dialog.present();

		Gtk.main();
	}

}
