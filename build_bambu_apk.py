import os
import sys
import shutil
import subprocess
from pathlib import Path

BASE_DIR = Path(r"C:\Users\MJ\android-tools")
JDK_DIR = BASE_DIR / "jdk-17"
SDK_DIR = BASE_DIR / "sdk"
CMDLINE_TOOLS_BIN = SDK_DIR / "cmdline-tools" / "latest" / "bin"
SDKMANAGER_BAT = CMDLINE_TOOLS_BIN / "sdkmanager.bat"
FLUTTER_BAT = Path(r"C:\Users\MJ\flutter\bin\flutter.bat")
PROJECT_DIR = Path(r"C:\Users\MJ\Documents\antigravity\zealous-kepler\bambu_studio_flutter")

LICENSES = {
    "android-sdk-license": (
        "8933bad161af4178b1185d1a37fbf41ea5269c55\n"
        "d56f5187479451eabf01fb78af6dfcb131a6481e\n"
        "24333f8a63b6825ea9c5514f83c2829b004d1fee\n"
    ),
    "android-sdk-preview-license": "84831b9409646a918e30573bab4c9c91346d8abd\n",
    "android-sdk-arm-dbt-license": "859f317696f67ef3d7f30a50a5560e7834b433a1\n",
    "android-googletv-license": "601085b94c27ae4b54738ac20f60ac69b83c4d6f\n",
    "google-gdk-license": "33b6a2b64f7901149e6f1406830e261778913d96\n",
    "mips-android-sysimage-license": "e9acab5b5fbb560a72cfa4e22e3432494f44fabc\n",
}

def accept_licenses():
    lic_dir = SDK_DIR / "licenses"
    lic_dir.mkdir(parents=True, exist_ok=True)
    for name, content in LICENSES.items():
        (lic_dir / name).write_text(content, encoding="utf-8")
    print(f"Android SDK licenses written to {lic_dir}")

def run_cmd(cmd, env=None, cwd=None, input_text=None):
    print(f"\n[RUN] {' '.join(str(c) for c in cmd)}")
    res = subprocess.run(
        cmd,
        input=input_text,
        env=env,
        cwd=cwd,
        text=True,
        encoding="latin-1",
        errors="replace"
    )
    if res.returncode != 0:
        print(f"Warning: Command exited with {res.returncode}")
    return res

def main():
    accept_licenses()

    custom_env = os.environ.copy()
    custom_env["JAVA_HOME"] = str(JDK_DIR)
    custom_env["ANDROID_HOME"] = str(SDK_DIR)
    custom_env["ANDROID_SDK_ROOT"] = str(SDK_DIR)
    new_path = f"{JDK_DIR / 'bin'};{CMDLINE_TOOLS_BIN};{SDK_DIR / 'platform-tools'};{custom_env.get('PATH', '')}"
    custom_env["PATH"] = new_path

    print("\nVerifying Java version...")
    run_cmd([str(JDK_DIR / "bin" / "java.exe"), "-version"], env=custom_env)

    print("\nInstalling platform-tools, platforms;android-34, build-tools;34.0.0...")
    run_cmd(
        [str(SDKMANAGER_BAT), f"--sdk_root={SDK_DIR}", "platform-tools", "platforms;android-34", "build-tools;34.0.0"],
        env=custom_env,
        input_text="y\ny\ny\ny\n"
    )

    print("\nRe-verifying licenses with sdkmanager --licenses...")
    run_cmd(
        [str(SDKMANAGER_BAT), f"--sdk_root={SDK_DIR}", "--licenses"],
        env=custom_env,
        input_text="y\ny\ny\ny\ny\ny\ny\ny\n"
    )

    print("\nConfiguring Flutter SDK with Android SDK path...")
    run_cmd([str(FLUTTER_BAT), "config", "--android-sdk", str(SDK_DIR)], env=custom_env)

    print("\nRunning Flutter doctor...")
    run_cmd([str(FLUTTER_BAT), "doctor"], env=custom_env)

    print("\nBuilding Release APK...")
    run_cmd(
        [str(FLUTTER_BAT), "build", "apk", "--release"],
        env=custom_env,
        cwd=str(PROJECT_DIR)
    )

    apk_path = PROJECT_DIR / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if apk_path.exists():
        size_mb = round(apk_path.stat().st_size / (1024 * 1024), 2)
        print(f"\n=======================================================")
        print(f"  SUCCESS! APK generated successfully!")
        print(f"  Path: {apk_path}")
        print(f"  Size: {size_mb} MB")
        print(f"=======================================================")
    else:
        print("\nChecking if debug APK was generated...")
        run_cmd(
            [str(FLUTTER_BAT), "build", "apk", "--debug"],
            env=custom_env,
            cwd=str(PROJECT_DIR)
        )

if __name__ == "__main__":
    main()
