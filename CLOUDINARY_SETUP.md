# Cloudinary Setup Guide for Attendance App

## Why Cloudinary?

- **FREE Plan**: 10GB storage, 25 credits/month (enough for thousands of images)
- **No payment required**: Free tier doesn't require credit card
- **Fast CDN**: Images delivered via global CDN
- **Easy to use**: Simple API integration

## Setup Steps

### 1. Create Free Cloudinary Account

1. Visit: https://cloudinary.com/users/register_free
2. Sign up with your email (no credit card needed)
3. Verify your email address
4. Log in to your dashboard

### 2. Get Your Credentials

#### Find Cloud Name:

1. After login, you'll see your **Dashboard**
2. Look for "Account Details" section
3. Copy your **Cloud name** (e.g., `dk1234abcd`)

#### Create Upload Preset:

1. Click **Settings** (gear icon) in the top right
2. Go to **Upload** tab
3. Scroll down to **Upload presets** section
4. Click **Add upload preset** button
5. Configure the preset:
   - **Preset name**: `attendance_app` (or any name you like)
   - **Signing mode**: Select **Unsigned** (important!)
   - **Folder**: Leave blank or set to `attendance` (optional)
   - **Unique filename**: Enable (recommended)
   - **Overwrite**: Disable (recommended)
6. Click **Save**
7. Copy the **Upload preset name**

### 3. Update Your App Configuration

Open the file: `lib/config/cloudinary_config.dart`

Replace the placeholder values:

```dart
class CloudinaryConfig {
  // Replace with your Cloud name from dashboard
  static const String cloudName = 'dk1234abcd';  // <-- YOUR CLOUD NAME

  // Replace with your upload preset name
  static const String uploadPreset = 'attendance_app';  // <-- YOUR PRESET

  static const bool cache = false;
}
```

### 4. Test the Upload

1. Run your app: `flutter run`
2. Navigate to the Complete Profile page
3. Select a profile picture and ID screenshot
4. Submit the form
5. Check your Cloudinary dashboard > Media Library to see uploaded images

## Features

✅ **Automatic organization**: Images stored in folders (`profilePictures`, `idScreenshots`)
✅ **Metadata**: Each upload includes userId and timestamp
✅ **Secure URLs**: HTTPS URLs returned for storing in Firestore
✅ **Image optimization**: Cloudinary automatically optimizes images
✅ **5MB size limit**: Built-in validation to prevent large uploads

## Free Tier Limits

- **Storage**: 10 GB
- **Bandwidth**: 10 GB/month
- **Transformations**: 25 credits/month
- **Images**: Thousands of images (depending on size)

For a typical attendance app with ~100 users:

- Profile pictures: ~100 MB (1MB each)
- ID screenshots: ~100 MB (1MB each)
- Total: ~200 MB (well within free tier!)

## Troubleshooting

### "Upload failed" error

- Check your cloud name and upload preset are correct
- Ensure upload preset is set to "Unsigned"
- Check internet connection

### "Invalid upload preset" error

- Verify the upload preset name matches exactly
- Make sure it's created in your Cloudinary dashboard
- Ensure signing mode is "Unsigned"

### Images not appearing in dashboard

- Check the Media Library in Cloudinary dashboard
- Look in the folder structure (profilePictures, idScreenshots)
- Images upload instantly but may take a second to appear

## Security Notes

- The current setup uses **unsigned uploads** for simplicity
- For production apps, consider implementing **signed uploads** with backend validation
- Cloudinary URLs are public but hard to guess
- You can add access control in Cloudinary settings if needed

## Need Help?

- Cloudinary Documentation: https://cloudinary.com/documentation
- Support: https://support.cloudinary.com
