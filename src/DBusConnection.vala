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

namespace FeedReader {

	[DBus (name = "org.gnome.feedreader")]
	public interface FeedDaemon : Object {

		public abstract void scheduleSync(int time) throws IOError;
		public abstract void startSync() throws IOError;
		public abstract void startInitSync() throws IOError;
		public abstract void changeArticle(string articleID, ArticleStatus status) throws IOError;
		public abstract void markFeedAsRead(string feedID, bool isCat) throws IOError;
		public abstract void markAllItemsRead() throws IOError;
		public abstract void updateBadge() throws IOError;


		// OFFLINE / ONLINE
		public abstract LoginResponse login(string plugin) throws IOError;
		public abstract LoginResponse isLoggedIn() throws IOError;
		public abstract bool isOnline() throws IOError;
		public abstract bool checkOnlineAsync() throws IOError;

		// GENERAL
		public abstract void resetAccount() throws IOError;
		public abstract void resetDB() throws IOError;
		public abstract int getVersion() throws IOError;
		public abstract void quit() throws IOError;

		// BACKEND INFOS
		public abstract bool hideCagetoryWhenEmtpy(string catID) throws IOError;
		public abstract bool supportCategories() throws IOError;
		public abstract bool supportFeedManipulation() throws IOError;
		public abstract bool supportMultiLevelCategories() throws IOError;
		public abstract bool supportTags() throws IOError;
		public abstract bool useMaxArticles() throws IOError;
		public abstract string? symbolicIcon() throws IOError;
		public abstract string? accountName() throws IOError;
		public abstract string? getServerURL() throws IOError;
		public abstract string uncategorizedID() throws IOError;

		// MANIPULATE TAGS
		public abstract string createTag(string caption) throws IOError;
		public abstract void tagArticle(string articleID, string tagID, bool add) throws IOError;
		public abstract void deleteTag(string tagID) throws IOError;
		public abstract void renameTag(string tagID, string newName) throws IOError;
		public abstract void updateTagColor(string tagID, int color) throws IOError;

		// MANIPULATE CATEGORIES
		public abstract string addCategory(string title, string parentID, bool createLocally) throws IOError;
		public abstract void removeCategory(string catID) throws IOError;
		public abstract void removeCategoryWithChildren(string catID) throws IOError;
		public abstract void moveCategory(string catID, string newParentID) throws IOError;
		public abstract void renameCategory(string catID, string newName) throws IOError;

		// MANIPULATE FEEDS
		public abstract void addFeed(string feedURL, string cat, bool isID, bool asynchron = true) throws IOError;
		public abstract void removeFeed(string feedID) throws IOError;
		public abstract void removeFeedOnlyFromCat(string m_feedID, string m_catID) throws IOError;
		public abstract void moveFeed(string feedID, string currentCatID, string? newCatID = null) throws IOError;
		public abstract void renameFeed(string feedID, string newName) throws IOError;
		public abstract void importOPML(string opml) throws IOError;

		// SIGNALS
		public signal void syncStarted();
		public signal void syncFinished();
		public signal void springCleanStarted();
		public signal void springCleanFinished();
		public signal void newFeedList();
		public signal void updateFeedList();
		public signal void newArticleList();
		public signal void updateArticleList();
		public signal void writeInterfaceState();
		public signal void showArticleListOverlay();
		public signal void setOffline();
		public signal void setOnline();
		public signal void feedAdded();
		public signal void opmlImported();
	}


	public class DBusConnection : GLib.Object {

		private static FeedDaemon? m_connection = null;

		public static FeedDaemon get_default()
		{
			if(m_connection == null)
				setup();

			return m_connection;
		}

		private DBusConnection()
		{

		}

		private static void setup()
		{
			try
			{
				m_connection = Bus.get_proxy_sync(BusType.SESSION, "org.gnome.feedreader", "/org/gnome/feedreader");
			}
			catch(IOError e)
			{
				logger.print(LogMessage.ERROR, "Failed to connect to daemon!");
				logger.print(LogMessage.ERROR, e.message);
				startDaemon();
			}

			checkDaemonVersion();
		}

		private static void startDaemon()
		{
			logger.print(LogMessage.INFO, "FeedReader: start daemon");
			try{
				GLib.Process.spawn_async("/", {"feedreader-daemon"}, null , GLib.SpawnFlags.SEARCH_PATH, null, null);
			}catch(GLib.SpawnError e){
				logger.print(LogMessage.ERROR, "spawning command line: %s".printf(e.message));
			}
		}

		public static void connectSignals(readerUI window)
		{
			if(m_connection == null)
				setup();

			m_connection.newFeedList.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: newFeedList");
				window.getContent().newFeedList();
			});

			m_connection.updateFeedList.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: updateFeedList");
				window.getContent().updateFeedList();
			});

			m_connection.newArticleList.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: newArticleList");
				window.getContent().newArticleList();
			});

			m_connection.updateArticleList.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: updateArticleList");
				window.getContent().updateArticleList();
			});

			m_connection.syncStarted.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: syncStarted");
				window.writeInterfaceState();
				window.setRefreshButton(true);
			});

			m_connection.syncFinished.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: syncFinished");
				window.getContent().syncFinished();
				window.showContent(Gtk.StackTransitionType.SLIDE_LEFT, true);
				window.setRefreshButton(false);
			});

			m_connection.springCleanStarted.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: springCleanStarted");
				window.showSpringClean();
			});

			m_connection.springCleanFinished.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: springCleanFinished");
				window.showContent();
			});

			m_connection.writeInterfaceState.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: writeInterfaceState");
				window.writeInterfaceState();
			});

			m_connection.showArticleListOverlay.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: showArticleListOverlay");
				window.getContent().showArticleListOverlay();
			});

			m_connection.setOffline.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: setOffline");
				window.setOffline();
			});

			m_connection.setOnline.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: setOnline");
				window.setOnline();
			});

			m_connection.feedAdded.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: feedAdded");
				window.getContent().footerSetReady();
			});

			m_connection.opmlImported.connect(() => {
				logger.print(LogMessage.DEBUG, "DBusConnection: opmlImported");
				window.getContent().footerSetReady();
			});
		}

		private static void checkDaemonVersion()
		{
			try
			{
				if(m_connection.getVersion() < Constants.DBusAPIVersion)
				{
					m_connection.quit();
					startDaemon();
				}
			}
			catch(GLib.Error e)
			{
				logger.print(LogMessage.ERROR, "checkDaemonVersion: %s".printf(e.message));
			}

		}

	}
}
