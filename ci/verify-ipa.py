"""Verify an actual exported IPA without exposing signing keys or profile data."""
import glob
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

ipas = glob.glob("build/ios/ipa/*.ipa")
if len(ipas) != 1:
    raise SystemExit("Expected exactly one exported IPA")
with zipfile.ZipFile(ipas[0]) as archive:
    roots = [n[:-len("Info.plist")] for n in archive.namelist()
             if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
    if len(roots) != 1:
        raise SystemExit("Expected exactly one main application")
    root = roots[0]
    info = plistlib.loads(archive.read(root + "Info.plist"))
    if info["CFBundleIdentifier"] != "uz.rentshare.ios":
        raise SystemExit("Bundle ID differs from the intended distribution app")
    plistlib.loads(archive.read(root + "PrivacyInfo.xcprivacy"))
    profile_bytes = archive.read(root + "embedded.mobileprovision")
    with tempfile.TemporaryDirectory() as directory:
        profile = Path(directory) / "profile.mobileprovision"
        profile.write_bytes(profile_bytes)
        decoded = subprocess.check_output(["security", "cms", "-D", "-i", str(profile)])
    profile_info = plistlib.loads(decoded)
    entitlements = profile_info["Entitlements"]
    if profile_info.get("ProvisionedDevices") or profile_info.get("ProvisionsAllDevices") or entitlements.get("get-task-allow"):
        raise SystemExit("Expected an App Store distribution profile, not a device development profile")
    if not entitlements["application-identifier"].endswith(".uz.rentshare.ios"):
        raise SystemExit("Distribution profile does not match the application")
    print("Verified exported App Store IPA:", info["CFBundleShortVersionString"], info["CFBundleVersion"])
