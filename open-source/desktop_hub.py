"""Basel Desktop Hub - independent MIT-licensed Android desktop controller."""
from __future__ import annotations

import os
import queue
import re
import shutil
import subprocess
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

APP_NAME = "Basel Desktop Hub"
PACKAGE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.]*$")
SERIAL_RE = re.compile(r"^[A-Za-z0-9_.:\-]+$")


class DesktopHub:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(APP_NAME)
        self.root.geometry("1000x680")
        self.root.minsize(760, 520)
        self.root.configure(bg="#0c171a")
        self.events: queue.Queue[tuple] = queue.Queue()
        self.devices: list[str] = []
        self.device_var = tk.StringVar()
        self.wifi_var = tk.StringVar()
        self.search_var = tk.StringVar()
        self.status_var = tk.StringVar(value="Ready. Connect an Android phone with USB debugging.")
        self.packages: list[str] = []
        self.setup_styles()
        self.draw()
        self.root.after(100, self.drain_events)
        self.refresh_devices()

    def setup_styles(self) -> None:
        st = ttk.Style()
        st.theme_use("clam")
        st.configure(".", font=("Segoe UI", 10))
        st.configure("Hub.TFrame", background="#0c171a")
        st.configure("Panel.TFrame", background="#142529")
        st.configure("Hub.TLabel", background="#0c171a", foreground="#e5f3f2")
        st.configure("Panel.TLabel", background="#142529", foreground="#e5f3f2")
        st.configure("Title.TLabel", background="#0c171a", foreground="#e5f3f2", font=("Segoe UI", 21, "bold"))
        st.configure("Sub.TLabel", background="#0c171a", foreground="#8ba5a5")
        st.configure("Hub.TButton", padding=(12, 9))
        st.configure("TCombobox", padding=5)
        st.configure("Treeview", background="#142529", foreground="#e5f3f2", fieldbackground="#142529", rowheight=31)
        st.configure("Treeview.Heading", background="#1c373b", foreground="#e5f3f2")
        st.map("Treeview", background=[("selected", "#099999")])
        st.configure("TEntry", padding=6)

    def draw(self) -> None:
        page = ttk.Frame(self.root, style="Hub.TFrame", padding=24)
        page.pack(fill="both", expand=True)
        ttk.Label(page, text=APP_NAME, style="Title.TLabel").pack(anchor="w")
        ttk.Label(page, text="Your Android apps on Windows  |  USB / Wi-Fi  |  ADB + scrcpy",
                  style="Sub.TLabel").pack(anchor="w", pady=(3, 16))

        connection = ttk.Frame(page, style="Panel.TFrame", padding=16)
        connection.pack(fill="x", pady=(0, 14))
        ttk.Label(connection, text="Device", style="Panel.TLabel").grid(row=0, column=0, sticky="w")
        self.device_box = ttk.Combobox(connection, textvariable=self.device_var, state="readonly", width=36)
        self.device_box.grid(row=1, column=0, sticky="ew", padx=(0, 8), pady=(5, 0))
        ttk.Button(connection, text="Refresh", command=self.refresh_devices).grid(row=1, column=1, padx=4)
        ttk.Button(connection, text="Mirror Screen", command=self.mirror).grid(row=1, column=2, padx=4)
        ttk.Button(connection, text="Screenshot", command=self.screenshot).grid(row=1, column=3, padx=4)
        ttk.Label(connection, text="Wi-Fi IP:port", style="Panel.TLabel").grid(row=2, column=0, sticky="w", pady=(12, 0))
        ttk.Entry(connection, textvariable=self.wifi_var).grid(row=3, column=0, sticky="ew", padx=(0, 8), pady=(5, 0))
        ttk.Button(connection, text="Connect", command=self.connect_wifi).grid(row=3, column=1, padx=4)
        ttk.Button(connection, text="Push File", command=self.push_file).grid(row=3, column=2, padx=4)
        connection.columnconfigure(0, weight=1)

        app_panel = ttk.Frame(page, style="Panel.TFrame", padding=16)
        app_panel.pack(fill="both", expand=True)
        head = ttk.Frame(app_panel, style="Panel.TFrame")
        head.pack(fill="x", pady=(0, 10))
        ttk.Label(head, text="Installed user applications", style="Panel.TLabel",
                  font=("Segoe UI", 12, "bold")).pack(side="left")
        ttk.Button(head, text="Load Apps", command=self.load_apps).pack(side="right")
        ttk.Entry(app_panel, textvariable=self.search_var).pack(fill="x", pady=(0, 10))
        self.search_var.trace_add("write", lambda *_: self.filter_apps())
        tree_frame = ttk.Frame(app_panel, style="Panel.TFrame")
        tree_frame.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(tree_frame, columns=("package",), show="headings", selectmode="browse")
        self.tree.heading("package", text="Android package name")
        self.tree.column("package", anchor="w")
        scroll = ttk.Scrollbar(tree_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scroll.set)
        self.tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.tree.bind("<Double-1>", lambda _: self.launch_app())
        footer = ttk.Frame(app_panel, style="Panel.TFrame")
        footer.pack(fill="x", pady=(12, 0))
        ttk.Button(footer, text="Launch selected app", command=self.launch_app).pack(side="left")
        ttk.Button(footer, text="Open app window", command=self.open_app_window).pack(side="left", padx=8)
        ttk.Label(page, textvariable=self.status_var, style="Sub.TLabel", wraplength=900).pack(
            anchor="w", pady=(14, 0))

    def run_background(self, task, on_success=None) -> None:
        def worker():
            try:
                result = task()
                self.events.put(("success", result, on_success))
            except Exception as exc:
                self.events.put(("error", str(exc), None))
        threading.Thread(target=worker, daemon=True).start()

    def drain_events(self) -> None:
        try:
            while True:
                kind, value, callback = self.events.get_nowait()
                if kind == "error":
                    self.status_var.set("Error: " + value)
                elif callback:
                    callback(value)
                else:
                    self.status_var.set(str(value))
        except queue.Empty:
            pass
        self.root.after(100, self.drain_events)

    @staticmethod
    def tool(name: str) -> str:
        resolved = shutil.which(name)
        if not resolved:
            raise RuntimeError(name + " not found in PATH. See README setup steps.")
        return resolved

    @classmethod
    def adb(cls, *args: str, binary: bool = False, timeout: int = 30):
        result = subprocess.run([cls.tool("adb"), *args], capture_output=True, timeout=timeout, check=False)
        if result.returncode:
            raise RuntimeError(result.stderr.decode("utf-8", "replace").strip()
                               or result.stdout.decode("utf-8", "replace").strip()
                               or "ADB command failed")
        return result.stdout if binary else result.stdout.decode("utf-8", "replace")

    def selected(self) -> str:
        serial = self.device_var.get().strip()
        if not serial or serial not in self.devices or not SERIAL_RE.fullmatch(serial):
            raise RuntimeError("Select an authorized connected device first.")
        return serial

    def refresh_devices(self) -> None:
        self.status_var.set("Checking connected Android devices...")
        def task():
            lines = self.adb("devices").splitlines()[1:]
            return [parts[0] for line in lines if (parts := line.split())
                    and len(parts) >= 2 and parts[1] == "device"]
        def done(devices):
            previous = self.device_var.get()
            self.devices = devices
            self.device_box["values"] = devices
            self.device_var.set(previous if previous in devices else devices[0] if devices else "")
            self.status_var.set(f"{len(devices)} authorized device(s) found. Enable USB debugging if none appear.")
        self.run_background(task, done)

    def connect_wifi(self) -> None:
        target = self.wifi_var.get().strip()
        match = re.fullmatch(r"((?:\d{1,3}\.){3}\d{1,3}):(\d{1,5})", target)
        if not match or any(int(p) > 255 for p in match.group(1).split(".")) or not 1 <= int(match.group(2)) <= 65535:
            messagebox.showerror("Invalid address", "Enter a valid IPv4 address and port, for example 192.168.1.20:5555")
            return
        self.run_background(lambda: self.adb("connect", target), lambda _: self.refresh_devices())

    def load_apps(self) -> None:
        try:
            serial = self.selected()
        except RuntimeError as exc:
            messagebox.showwarning("Device", str(exc))
            return
        self.status_var.set("Loading installed third-party packages...")
        def task():
            output = self.adb("-s", serial, "shell", "pm", "list", "packages", "-3", timeout=60)
            return sorted(line.removeprefix("package:").strip() for line in output.splitlines()
                          if line.startswith("package:"))
        def done(packages):
            self.packages = packages
            self.filter_apps()
            self.status_var.set(f"Loaded {len(packages)} user-installed packages.")
        self.run_background(task, done)

    def filter_apps(self) -> None:
        term = self.search_var.get().lower().strip()
        self.tree.delete(*self.tree.get_children())
        for pkg in self.packages:
            if term in pkg.lower():
                self.tree.insert("", "end", values=(pkg,))

    def package(self) -> str:
        chosen = self.tree.selection()
        if not chosen:
            raise RuntimeError("Choose an Android app from the list.")
        package = self.tree.item(chosen[0], "values")[0]
        if not PACKAGE_RE.fullmatch(package):
            raise RuntimeError("Invalid package name.")
        return package

    def launch_app(self) -> None:
        try:
            serial, package = self.selected(), self.package()
        except RuntimeError as exc:
            messagebox.showwarning("App", str(exc))
            return
        self.run_background(lambda: self.adb("-s", serial, "shell", "monkey",
                                               "-p", package, "-c",
                                               "android.intent.category.LAUNCHER", "1"),
                            lambda _: self.status_var.set("Launch requested: " + package))

    def mirror(self) -> None:
        try:
            serial = self.selected()
            subprocess.Popen([self.tool("scrcpy"), "-s", serial, "--window-title", APP_NAME],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.status_var.set("Screen mirror started.")
        except (RuntimeError, OSError) as exc:
            messagebox.showerror("Mirror", str(exc))

    def open_app_window(self) -> None:
        try:
            serial, package = self.selected(), self.package()
            self.adb_tool_launch(serial, package)
        except (RuntimeError, OSError) as exc:
            messagebox.showerror("App window", str(exc))

    def adb_tool_launch(self, serial: str, package: str) -> None:
        # Open the app then mirror the device. This MVP does NOT yet create
        # per-app virtual displays or independent Android task windows.
        self.launch_app()
        subprocess.Popen([self.tool("scrcpy"), "-s", serial, "--window-title", package],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.status_var.set("Mirroring device while opening: " + package)

    def screenshot(self) -> None:
        try:
            serial = self.selected()
        except RuntimeError as exc:
            messagebox.showwarning("Device", str(exc))
            return
        destination = filedialog.asksaveasfilename(defaultextension=".png",
                                                    filetypes=[("PNG image", "*.png")])
        if not destination:
            return
        def task():
            data = self.adb("-s", serial, "exec-out", "screencap", "-p", binary=True, timeout=45)
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise RuntimeError("Device returned an invalid screenshot.")
            Path(destination).write_bytes(data)
            return "Screenshot saved: " + destination
        self.run_background(task)

    def push_file(self) -> None:
        try:
            serial = self.selected()
        except RuntimeError as exc:
            messagebox.showwarning("Device", str(exc))
            return
        source = filedialog.askopenfilename()
        if not source:
            return
        target = "/sdcard/Download/" + os.path.basename(source)
        self.run_background(lambda: self.adb("-s", serial, "push", source, target, timeout=180),
                            lambda _: self.status_var.set("Transferred to: " + target))


if __name__ == "__main__":
    window = tk.Tk()
    DesktopHub(window)
    window.mainloop()
