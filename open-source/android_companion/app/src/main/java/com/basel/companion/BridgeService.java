package com.basel.companion;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.BatteryManager;
import android.os.IBinder;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

public class BridgeService extends Service {
  private volatile boolean running;
  private ServerSocket server;
  static String getToken(Context context) {
    android.content.SharedPreferences prefs = context.getSharedPreferences("bridge", MODE_PRIVATE);
    String token = prefs.getString("token", "");
    if (token == null || token.isEmpty()) {
      byte[] bytes = new byte[24];
      new SecureRandom().nextBytes(bytes);
      StringBuilder out = new StringBuilder();
      for (byte b : bytes) out.append(String.format("%02x", b & 0xff));
      token = out.toString();
      prefs.edit().putString("token", token).apply();
    }
    return token;
  }
  @Override public void onCreate() {
    super.onCreate();
    NotificationManager manager = getSystemService(NotificationManager.class);
    manager.createNotificationChannel(new NotificationChannel("bridge", "Basel local bridge", NotificationManager.IMPORTANCE_LOW));
    PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
    Notification notification = new Notification.Builder(this, "bridge")
      .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
      .setContentTitle("Basel Companion is active")
      .setContentText("Local connection available for your desktop")
      .setContentIntent(open).setOngoing(true).build();
    startForeground(7, notification);
    running = true;
    new Thread(this::serve, "basel-local-bridge").start();
  }
  @Override public int onStartCommand(Intent intent, int flags, int id) { return START_NOT_STICKY; }
  private void serve() {
    try (ServerSocket listener = new ServerSocket(37971, 8, InetAddress.getByName("127.0.0.1"))) {
      server = listener;
      while (running) {
        try (Socket socket = listener.accept()) {
          socket.setSoTimeout(2000);
          BufferedReader reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8));
          String request = reader.readLine();
          String token = "";
          for (int i = 0; i < 40; i++) {
            String line = reader.readLine();
            if (line == null || line.isEmpty()) break;
            if (line.toLowerCase(java.util.Locale.ROOT).startsWith("x-basel-token:"))
              token = line.substring(line.indexOf(':') + 1).trim();
          }
          boolean allowed = request != null && request.startsWith("GET /status ") &&
            java.security.MessageDigest.isEqual(token.getBytes(StandardCharsets.UTF_8),
              getToken(this).getBytes(StandardCharsets.UTF_8));
          byte[] body = (allowed ? snapshot() : "{\"error\":\"unauthorized\"}").getBytes(StandardCharsets.UTF_8);
          OutputStream output = socket.getOutputStream();
          String headers = "HTTP/1.1 " + (allowed ? "200 OK" : "403 Forbidden") +
            "\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: " + body.length + "\r\n\r\n";
          output.write(headers.getBytes(StandardCharsets.US_ASCII));
          output.write(body);
          output.flush();
        } catch (Exception ignored) { }
      }
    } catch (Exception ignored) { stopSelf(); }
  }
  private String snapshot() {
    JSONObject data = new JSONObject();
    try {
      Intent battery = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
      int level = battery == null ? -1 : battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
      int scale = battery == null ? -1 : battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
      data.put("battery", level >= 0 && scale > 0 ? level * 100 / scale : -1);
      ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
      Network network = cm.getActiveNetwork();
      NetworkCapabilities capabilities = cm.getNetworkCapabilities(network);
      data.put("network", capabilities == null ? "offline" :
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ? "Wi-Fi" :
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ? "Mobile" : "Other");
      data.put("notificationAccess", NotificationBridge.instance != null);
      data.put("notifications", NotificationBridge.snapshot());
    } catch (Exception ignored) { }
    return data.toString();
  }
  @Override public void onDestroy() {
    running = false;
    try { if (server != null) server.close(); } catch (Exception ignored) { }
    super.onDestroy();
  }
  @Override public IBinder onBind(Intent intent) { return null; }
}
