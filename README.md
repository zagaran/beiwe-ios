### Building the Beiwe iOS app
1. Install Cocoapods.
2. Inside this project directory (inside the `beiwe-ios` directory), run `pod install`.
3. Install a `GoogleService-Info.plist` file.
    1. Note: this is connected to your specific Firebase account.  If you're using the Beiwe Service Center but still want to build your own version of the Beiwe iOS app, you'll need to ask someone at the Onnela Lab to provide this file to you.
    2. To add the file to the Xcode project, open it in Finder, and drag it into the Xcode project navigator.  It's not enough to move it into the beiwe-ios directory using Finder or `mv`/`cp` in Terminal.
3. Open Xcode.
    1. To build for the Simulator, click the "Run" arrow button.
    2. To build for release, click Product -> Archive.

### Build Configurations
There are two important Build Configurations:
* "Beiwe": the study server is hardcoded to studies.beiwe.org
* "Beiwe2": the study server URL gets set after you install the app, on the registration screen.
