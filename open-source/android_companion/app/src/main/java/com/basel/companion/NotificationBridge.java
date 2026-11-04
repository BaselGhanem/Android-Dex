package com.basel.companion;

import android.app.Notification;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import org.json.JSONArray;
import org.json.JSONObject;

public class NotificationBridge extends NotificationListenerService {
  static volatile NotificationBridge instance;
  @Override public void onListenerConnected() { instance = this; }
  @Override public void onListenerDisconnected() { instance = null; }
  @Override public void onDestroy() { instance = null; super.onDestroy(); }
  static JSONArray snapshot() {
    JSONArray result = new JSONArray();
    NotificationBridge listener = instance;
    if (listener == null) return result;
    try {
      StatusBarNotification[] notifications = listener.getActiveNotifications();
      if (notifications == null) return result;
      for (StatusBarNotification n : notifications) {
        if (result.length() >= 50) break;
        JSONObject item = new JSONObject();
        item.put("package", n.getPackageName());
        item.put("title", String.valueOf(n.getNotification().extras.getCharSequence(Notification.EXTRA_TITLE, "")));
        item.put("text", String.valueOf(n.getNotification().extras.getCharSequence(Notification.EXTRA_TEXT, "")));
        item.put("time", n.getPostTime());
        result.put(item);
      }
    } catch (Exception ignored) { }
    return result;
  }
}
