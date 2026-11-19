package org.ranchsim.notify;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Wakes up at the time RanchNotify.schedule asked for and puts the notice in the phone's shade. */
public class AlarmReceiver extends BroadcastReceiver {
	static final String CHANNEL = "ranch";

	@Override
	public void onReceive(Context c, Intent i) {
		NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm == null) {
			return;
		}
		if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
			nm.createNotificationChannel(new NotificationChannel(CHANNEL, "رنچ", NotificationManager.IMPORTANCE_DEFAULT));
		}
		String title = i.getStringExtra("title");
		String text = i.getStringExtra("text");
		int icon = c.getResources().getIdentifier("ranch_notify_icon", "drawable", c.getPackageName());
		if (icon == 0) {
			icon = c.getApplicationInfo().icon;
		}
		Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(c, CHANNEL) : new Notification.Builder(c);
		b.setSmallIcon(icon)
				.setContentTitle(title)
				.setContentText(text)
				.setStyle(new Notification.BigTextStyle().bigText(text))
				.setAutoCancel(true);
		Intent open = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
		if (open != null) { // a tap opens the game
			b.setContentIntent(PendingIntent.getActivity(c, 0, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
		}
		nm.notify(i.getIntExtra("id", 1), b.build());
	}
}
