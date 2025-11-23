/// Cloudinary Configuration
///
/// To set up Cloudinary (FREE):
/// 1. Go to https://cloudinary.com/users/register_free
/// 2. Sign up for a free account (10GB storage, 25 credits/month)
/// 3. After login, go to Dashboard
/// 4. Find your Cloud Name (e.g., "your-cloud-name")
/// 5. Go to Settings > Upload > Upload presets
/// 6. Click "Add upload preset"
/// 7. Set Signing Mode to "Unsigned"
/// 8. Set Upload preset name (e.g., "attendance_app")
/// 9. Under "Folder" you can set default folder or leave blank
/// 10. Save and copy the preset name
/// 11. Replace the values below with your credentials

class CloudinaryConfig {
  // Replace with your Cloudinary cloud name from dashboard
  static const String cloudName = 'du3qpurjj';

  // Replace with your unsigned upload preset name (NO SPACES!)
  // If your preset has spaces, recreate it without spaces in Cloudinary dashboard
  static const String uploadPreset = 'attendance_app';

  // Optional: Set to true to enable caching
  static const bool cache = false;
}
