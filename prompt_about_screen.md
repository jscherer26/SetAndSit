# Prompt for Android Studio Agent

Please create a new About screen for my Flutter app, named SetAndSit. The screen should be accessible via a ListTile placed at the very bottom of my existing Settings menu, featuring an information icon and the title 'About SetAndSit'.

When tapped, it should navigate to a dedicated About screen file. Please implement the following requirements:

1. Architecture & Dependencies: Please ensure the screen is built as a separate widget file. Use `package_info_plus` to dynamically fetch and display the app's version and build number at the top of the screen (formatted as 'v[version] (Build [buildNumber])'). Use `url_launcher` to handle external link taps.
2. Theming: The UI must strictly utilize `Theme.of(context)` for its typography and color scheme, ensuring it natively supports and looks great in both light and dark modes without hardcoded colors.
3. Content and Layout:
   - Mission Statement: Display the following text prominently: 'Trauma-sensitive practices designed to fit your unique timeframe.'
   - Credits: Include a section crediting our voice technology: 'Powered by ElevenLabs 11 v4 voice technology.'
   - Feedback: Add a button or list tile labeled 'Send Feedback' with the subtitle 'Help us improve during pre-release by sharing your experience.' Tapping this should open the default mail client pre-populated to codejuggler26@gmail.com.
   - Open Source Notices: Include a button that triggers Flutter’s built-in showLicensePage() method to display open-source licenses.

Keep the layout clean, uncluttered, and properly padded for mobile screens.