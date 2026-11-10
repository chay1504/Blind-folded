package com.chay.blindfold;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.text.InputType;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private final ExecutorService network = Executors.newSingleThreadExecutor();
    private boolean pending;
    private boolean paired;
    private String code;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        showSetup();
    }

    private void showSetup() {
        LinearLayout setup = new LinearLayout(this);
        setup.setOrientation(LinearLayout.VERTICAL);
        setup.setGravity(Gravity.CENTER);
        setup.setPadding(dp(28), dp(28), dp(28), dp(28));
        setup.setBackgroundColor(Color.rgb(19, 23, 32));

        TextView title = new TextView(this);
        title.setText("Codex Remote");
        title.setTextSize(28);
        title.setTypeface(null, Typeface.BOLD);
        setup.addView(title);

        TextView status = new TextView(this);
        status.setText("Connect by USB. Enter the code shown on the laptop.");
        status.setPadding(0, dp(14), 0, dp(14));
        setup.addView(status);

        EditText entry = new EditText(this);
        entry.setSingleLine(true);
        entry.setHint("Pairing code");
        entry.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        setup.addView(entry, new LinearLayout.LayoutParams(-1, -2));

        Button connect = new Button(this);
        connect.setText("Connect");
        connect.setOnClickListener(v -> {
            code = entry.getText().toString().trim();
            if (!code.matches("[0-9]{6}")) {
                status.setText("Enter the 6-digit code from the laptop.");
                return;
            }
            connect.setEnabled(false);
            getSystemService(InputMethodManager.class).hideSoftInputFromWindow(entry.getWindowToken(), 0);
            status.setText("Connecting...");
            request("/status", success -> {
                if (success) {
                    paired = true;
                    showRemote();
                    buzz(true);
                } else {
                    connect.setEnabled(true);
                    status.setText("Check the USB connection and the code, then try again.");
                }
            });
        });
        setup.addView(connect, new LinearLayout.LayoutParams(-1, -2));
        setContentView(setup);
    }

    private void showRemote() {
        LinearLayout surface = new LinearLayout(this);
        surface.setOrientation(LinearLayout.VERTICAL);
        addHalf(surface, "Dictate", "/dictation", 0xff182744);
        addHalf(surface, "Voice chat", "/voice", 0xff14372f);
        setContentView(surface);
        hideBars();
    }

    private void addHalf(LinearLayout surface, String label, String route, int color) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(label);
        button.setTypeface(null, Typeface.BOLD);
        button.setTextSize(25);
        button.setTextColor(Color.WHITE);
        GradientDrawable background = new GradientDrawable();
        background.setColor(color);
        background.setStroke(dp(1), 0xff0d121c);
        button.setBackground(background);
        button.setOnClickListener(v -> request(route, this::buzz));
        surface.addView(button, new LinearLayout.LayoutParams(-1, 0, 1));
    }

    private interface Result {
        void completed(boolean success);
    }

    private void request(String route, Result result) {
        if (pending) return;
        pending = true;
        String sessionCode = code;
        network.execute(() -> {
            boolean success = send(route, sessionCode);
            runOnUiThread(() -> {
                pending = false;
                if (!isDestroyed()) result.completed(success);
            });
        });
    }

    private boolean send(String route, String sessionCode) {
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress("127.0.0.1", 18763), 1400);
            socket.setSoTimeout(2400);
            socket.getOutputStream().write((sessionCode + " " + route + "\n").getBytes(StandardCharsets.US_ASCII));
            InputStream reply = socket.getInputStream();
            return reply.read() == 'O' && reply.read() == 'K' && reply.read() == '\n';
        } catch (Exception error) {
            Log.w("CodexRemote", "Receiver connection failed", error);
            return false;
        }
    }

    private void buzz(boolean success) {
        Vibrator vibrator = getSystemService(Vibrator.class);
        if (vibrator == null || !vibrator.hasVibrator()) return;
        vibrator.vibrate(success
            ? VibrationEffect.createOneShot(65, VibrationEffect.DEFAULT_AMPLITUDE)
            : VibrationEffect.createWaveform(new long[]{0, 180, 85, 180}, -1));
    }

    private void hideBars() {
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (focused && paired) hideBars();
    }

    @Override protected void onDestroy() {
        network.shutdownNow();
        super.onDestroy();
    }

    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
