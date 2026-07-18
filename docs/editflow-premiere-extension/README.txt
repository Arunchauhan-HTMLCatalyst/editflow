EditFlow OS Premiere Pro Extension
==================================

This extension allows you to load the complete EditFlow Workspace panel natively inside Adobe Premiere Pro.

Installation Instructions for Windows:
--------------------------------------
1. Copy the "editflow-premiere-extension" folder.
2. Open Windows File Explorer and navigate to:
   C:\Users\<Your-Username>\AppData\Roaming\Adobe\CEP\extensions\
   (If the "CEP" or "extensions" folder does not exist, create them manually).
3. Paste the "editflow-premiere-extension" folder inside the "extensions" folder.

Enable Unsigned Extensions (Mandatory for local panels):
--------------------------------------------------------
By default, Adobe Premiere Pro blocks unsigned extension panels. Run these steps to enable debug mode:
1. Press "Win + R", type "regedit", and press Enter to open Registry Editor.
2. Navigate to:
   HKEY_CURRENT_USER\Software\Adobe\CSXS.9  (For Premiere 2019/2020)
   HKEY_CURRENT_USER\Software\Adobe\CSXS.10 (For Premiere 2021)
   HKEY_CURRENT_USER\Software\Adobe\CSXS.11 (For Premiere 2022/2023)
   HKEY_CURRENT_USER\Software\Adobe\CSXS.12 (For Premiere 2024+)
3. Right-click in the empty space on the right, select "New > String Value", name it "PlayerDebugMode", and press Enter.
4. Double-click "PlayerDebugMode", set its Value Data to "1", and click OK.
5. Close Registry Editor.

How to open the Panel in Premiere Pro:
--------------------------------------
1. Start (or restart) Adobe Premiere Pro.
2. Go to the top menu: Window > Extensions > EditFlow OS.
3. The EditFlow workspace panel will open! Dock it anywhere you like.
