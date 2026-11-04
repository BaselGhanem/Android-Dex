package com.basel.companion;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
  @Override public void onCreate(Bundle saved) {
    super.onCreate(saved);
    LinearLayout layout = new LinearLayout(this);
    layout.setOrientation(LinearLayout.VERTICAL);
    layout.setPadding(36, 70, 36, 30);
    layout.setBackgroundColor(Color.rgb(11, 22, 25));
    TextView title = new TextView(this);
    title.setText("Basel Companion");
    title.setTextSize(27);
    title.setTextColor(Color.WHITE);
    layout.addView(title);
    TextView subtitle = new TextView(this);
    subtitle.setText("Your Galaxy, connected to your desk.\n\nStart the local bridge, grant notification access if you want to see notifications, then copy your private access code into Basel Hub.");
    subtitle.setTextColor(Color.LTGRAY);
    subtitle.setTextSize(16);
    subtitle.setPadding(0, 25, 0, 25);
    layout.addView(subtitle);
    TextView code = new TextView(this);
    code.setText("Access code: " + BridgeService.getToken(this));
    code.setTextColor(Color.rgb(9, 153, 153));
    code.setTextSize(17);
    code.setTextIsSelectable(true);
    code.setGravity(Gravity.CENTER);
    layout.addView(code);
    Button access = new Button(this);
    access.setText("Allow notification access");
    access.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)));
    layout.addView(access);
    Button start = new Button(this);
    start.setText("Start my local bridge");
    start.setOnClickListener(v -> {
      if (Build.VERSION.SDK_INT >= 33 &&
          checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
        requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
      }
      startForegroundService(new Intent(this, BridgeService.class));
    });
    layout.addView(start);
    Button stop = new Button(this);
    stop.setText("Stop bridge");
    stop.setOnClickListener(v -> stopService(new Intent(this, BridgeService.class)));
    layout.addView(stop);
    setContentView(layout);
  }
}
