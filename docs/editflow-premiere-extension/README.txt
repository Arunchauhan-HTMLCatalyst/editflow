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
By default, Adobe Premiere Pro blocks unsigned extension panels. We have included a registry file to enable this automatically:
1. Double-click the "enable-debug-mode.reg" file located inside this folder.
2. Click "Yes" on the security prompt, and click "OK" to apply.
(This automatically sets the "PlayerDebugMode" registry string for CSXS versions 9 to 12).

How to open the Panel in Premiere Pro:
--------------------------------------
1. Start (or restart) Adobe Premiere Pro.
2. Go to the top menu: Window > Extensions > EditFlow OS.
3. The EditFlow workspace panel will open! Dock it anywhere you like.
