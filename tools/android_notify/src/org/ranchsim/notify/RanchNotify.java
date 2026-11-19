package org.ranchsim.notify;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Phone notifications for Ranch: the game asks for a few to be shown later (a building done, the truck
 * at the gate) when it goes to the background, and takes them back when it comes to the front again.
 * Reached from GDScript as Engine.get_singleton("RanchNotify").
 */
public class RanchNotify extends GodotPlugin {
	static final int MAX = 8; // ids 1..MAX

	public RanchNotify(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "RanchNotify";
	}

	private Context context() {
		Activity a = getActivity();
		return a != null ? a.getApplicationContext() : null;
	}

	/** Android 13 and up: the player has to allow notifications once. */
	@UsedByGodot
	public void ask_permission() {
		Activity a = getActivity();
		if (a == null || Build.VERSION.SDK_INT < 33) {
			return;
		}
		if (a.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
			a.requestPermissions(new String[] { Manifest.permission.POST_NOTIFICATIONS }, 4171);
		}
	}

	/** Shows `text` in `seconds` from now, even with the game closed. The same id replaces the earlier one. */
	@UsedByGodot
	public void schedule(int id, int seconds, String title, String text) {
		Context c = context();
		if (c == null || id < 1 || id > MAX) {
			return;
		}
		AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
		Intent i = new Intent(c, AlarmReceiver.class);
		i.putExtra("id", id);
		i.putExtra("title", title);
		i.putExtra("text", text);
		PendingIntent p = PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
		long at = System.currentTimeMillis() + Math.max(1, seconds) * 1000L;
		am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, p); // no exact-alarm permission needed
	}

	/** Takes back everything scheduled and clears what's showing: the player is back in the game. */
	@UsedByGodot
	public void cancel_all() {
		Context c = context();
		if (c == null) {
			return;
		}
		AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
		for (int id = 1; id <= MAX; id++) {
			PendingIntent p = PendingIntent.getBroadcast(c, id, new Intent(c, AlarmReceiver.class),
					PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
			if (p != null) {
				am.cancel(p);
				p.cancel();
			}
		}
		NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
		nm.cancelAll();
	}
}
