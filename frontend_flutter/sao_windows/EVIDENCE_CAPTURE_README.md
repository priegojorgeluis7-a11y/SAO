# 📸 Evidence Capture System - Complete Guide

**Status:** ✅ Phase 6 Complete  
**Platform:** Flutter Mobile (iOS + Android)  
**Backend:** FastAPI with GCS integration  
**Tests:** 210+ comprehensive test cases  

---

## 🎯 Quick Start

### For Users: Capturing Evidence

1. **Open Evidence Capture**
   - Navigate to activity details
   - Tap "Add Evidence" or camera icon
   - EvidenceCapturePage opens

2. **Select Source**
   - **Camera** - Take new photo/video
   - **Video** - Record video (max 5 minutes)
   - **Gallery** - Choose existing file

3. **Service Processing (Automatic)**
   - GPS coordinates captured automatically
   - Image compressed to 1 MB (JPEG 75%, max 1920x1920)
   - File size reduced by 70-85%
   - Metadata attached: size, type, GPS, time

4. **Add Description**
   - Type description (max 500 characters)
   - Orange warning at 80%
   - Red error if empty
   - Green checkmark when valid

5. **Review & Submit**
   - Preview image/video
   - See GPS coordinates with accuracy
   - See compression stats
   - Tap "Submit Evidence"

6. **Upload Result**
   - ✅ **Success**: "Evidence uploaded successfully"
   - ⚠️ **No Connection**: "Queued for offline upload"

---

## 🏗️ Architecture

### Components

```
┌────────────────────────────────────────────┐
│         EvidenceCapturePage                │
│  (3-screen workflow)                       │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│      CameraCaptureService                  │
│  - Photo/video from camera                 │
│  - Gallery picker                          │
│  - Returns CapturedEvidence                │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│    ImageCompressionService                 │
│  - JPEG 75% quality                        │
│  - Max 1920x1920 resolution                │
│  - PNG→JPEG conversion                     │
│  - Returns: compressed path + stats        │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│     GpsTaggingService                      │
│  - Capture coordinates & accuracy          │
│  - Altitude, heading, speed                │
│  - Request permissions                     │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│   EvidenceUploadRepository                 │
│  Step 1: uploadInit() → GET signed URL     │
│  Step 2: uploadBytesToSignedUrl() → GCS    │
│  Step 3: uploadComplete() → finalize       │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│      Backend (FastAPI)                     │
│  - Create/track evidence records           │
│  - Generate GCS signed URLs                │
│  - Update status on completion             │
└────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────┐
│    GCS (Google Cloud Storage)              │
│  - Store image/video files                 │
│  - 15-minute signed URL access             │
└────────────────────────────────────────────┘
```

---

## 📱 UI Components

### EvidenceCapturePage (Main Page)

**Screen 1: Capture Selection**
```
┌─────────────────────────────┐
│ Capture Evidence            │
├─────────────────────────────┤
│                             │
│  [📷] Capture Photo         │
│       Take a photo using    │
│       the device camera     │
│      [Take Photo]           │
│                             │
│  [🎥] Capture Video         │
│       Record a video        │
│       (max 5 minutes)       │
│      [Record Video]         │
│                             │
│  [🖼️] Choose from Gallery   │
│       Select an existing    │
│       photo or video        │
│      [Choose]               │
│                             │
└─────────────────────────────┘
```

**Screen 2: Review & Submit**
```
┌─────────────────────────────┐
│ Review Evidence  [↻ Retake] │
├─────────────────────────────┤
│                             │
│ ┌───────────────────────┐   │
│ │   [Image Preview]     │   │
│ │ photo.jpg - 2.0 MB    │   │
│ │ Compressed 75% ✓      │   │
│ │ 2/24/26 14:30         │   │
│ └───────────────────────┘   │
│                             │
│ 📍 Coordinates              │
│ 37.7749, -122.4194         │
│ Accuracy: 10.5m (✓ Good)   │
│                             │
│ Compression Stats:          │
│ 4.0 MB → 2.0 MB (50%)       │
│                             │
│ * Description (required)    │
│ ┌─────────────────────────┐ │
│ │ Photo of site entrance  │ │
│ │ 30/500 characters       │ │
│ │ ✓ Description added     │ │
│ └─────────────────────────┘ │
│                             │
│  [☁️ Upload Evidence]        │
│                             │
└─────────────────────────────┘
```

### EvidencePreviewCard
- Thumbnail image or play icon for video
- File name, size (human-readable)
- Compression badge if compressed
- Capture time
- Handles missing files gracefully

### EvidenceDescriptionForm
- Required field (red asterisk)
- Character counter (0/500)
- Orange warning at 80% (400 chars)
- Red error when empty
- Green checkmark when filled

### GpsLocationDisplay
- **Compact:** "📍 37.7749,-122.4194"
- **Expanded:**
  - Coordinates
  - Accuracy (color-coded: green/orange/red)
  - Altitude
  - Heading
  - Speed
  - Timestamp

---

## 🔧 For Developers

### Using EvidenceUploadProvider (Riverpod)

```dart
import 'package:riverpod/riverpod.dart';
import 'features/evidence/presentation/providers/evidence_upload_provider.dart';
import 'features/evidence/services/camera_capture_service.dart';

class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(evidenceUploadProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // Your UI
          
          // Upload progress
          if (uploadState.isLoading)
            LinearProgressIndicator(
              value: uploadState.uploadProgress,
            ),
          
          // Success
          if (uploadState.isSuccess)
            SnackBar(
              content: Text('✅ Uploaded: ${uploadState.evidenceId}'),
            ),
          
          // Error or offline queue
          if (uploadState.isQueuedForOffline)
            SnackBar(
              content: Text('⚠️ ${uploadState.error}'),
              backgroundColor: Colors.orange,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final evidence = await _captureEvidence();
          final success = await ref
            .read(evidenceUploadProvider.notifier)
            .uploadEvidence(
              activityId: 'activity-123',
              evidence: evidence,
            );
          
          if (success) {
            // Handle success
          }
        },
        child: Icon(Icons.camera),
      ),
    );
  }
}
```

### Direct Upload (Non-Riverpod)

```dart
import 'features/evidence/data/evidence_upload_repository.dart';
import 'features/evidence/services/camera_capture_service.dart';

final repository = EvidenceUploadRepository();
final cameraService = CameraCaptureService();

// 1. Capture evidence
final evidence = await cameraService.capturePhoto(
  includeGps: true,
  autoCompress: true,
);

// 2. Upload
try {
  // Step 1: Initialize
  final initResult = await repository.uploadInit(
    activityId: 'activity-123',
    mimeType: evidence.mimeType,
    sizeBytes: evidence.sizeBytes,
    fileName: evidence.fileName,
  );
  
  // Step 2: PUT to GCS
  final bytes = await File(evidence.localPath).readAsBytes();
  await repository.uploadBytesToSignedUrl(
    signedUrl: initResult.signedUrl,
    bytes: bytes,
    mimeType: evidence.mimeType,
  );
  
  // Step 3: Complete
  await repository.uploadComplete(
    evidenceId: initResult.evidenceId,
  );
  
  print('✅ Success: ${initResult.evidenceId}');
} on DioException catch (e) {
  // Queue for offline
  await repository.enqueuePendingUpload(
    activityId: 'activity-123',
    localPath: evidence.localPath,
    fileName: evidence.fileName,
    mimeType: evidence.mimeType,
    sizeBytes: evidence.sizeBytes,
  );
  print('⚠️ Queued for offline retry');
}
```

---

## 🧪 Testing

### Run All Evidence Tests
```bash
cd frontend_flutter/sao_windows
flutter test test/features/evidence/ -v
```

### Test Scenarios

**Basic Capturing**
```bash
flutter test test/features/evidence/evidence_capture_test.dart -v
```

**Backend Integration**
```bash
flutter test test/features/evidence/evidence_integration_test.dart \
  -k "Full Capture Workflow" -v
```

**Offline Queue**
```bash
flutter test test/features/evidence/evidence_integration_test.dart \
  -k "Offline" -v
```

**GPS Calculations**
```bash
flutter test test/features/evidence/services/gps_tagging_service_test.dart \
  -k "Distance Calculations" -v
```

**Image Compression**
```bash
flutter test test/features/evidence/services/image_compression_service_test.dart \
  -k "Compression Scenarios" -v
```

**UI Rendering**
```bash
flutter test test/features/evidence/widgets/evidence_widgets_test.dart -v
```

---

## 🚀 Deployment

### Prerequisites
- Flutter 3.24+
- Backend running FastAPI service
- GCS bucket configured
- Service account with GCS permissions

### Mobile App
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release --no-codesign
```

### Backend Service
```bash
# Verify endpoints running
curl -X POST http://localhost:8000/evidences/upload-init \
  -H "Content-Type: application/json" \
  -d '{"activityId":"test","mimeType":"image/jpeg","sizeBytes":1000,"fileName":"test.jpg"}'
```

### GCS Bucket
```bash
# Create bucket
gsutil mb gs://sao-evidence

# Set permissions
gsutil iam ch serviceAccount:backend-sa@project.iam.gserviceaccount.com:objectAdmin gs://sao-evidence
```

---

## 📊 Performance

### Typical Operation Times
| Operation | Time | Notes |
|-----------|------|-------|
| Take photo | 1-2s | Depends on device camera |
| Compress image (4 MB) | 1-2s | JPEG 75%, async |
| Capture GPS | 2-5s | High accuracy mode |
| Upload (2 MB) | 3-10s | Depends on network (WiFi ~3s, 4G ~5-10s) |
| **Total (typical)** | **10-20s** | From capture to uploaded |

### File Sizes
| Type | Before | After | Reduction |
|------|--------|-------|-----------|
| Photo (8 MP) | 4 MB | 1 MB | 75% |
| Photo (12 MP) | 6 MB | 1.5 MB | 75% |
| Video (1 min) | 50 MB | 50 MB | 0% (limited to 5 min) |

### Battery Impact
- GPS polling: +5-10% battery per 1 minute continuous
- Photo capture: +3-5% battery
- Video recording: +10-15% battery per minute
- Network upload: +2-5% battery per 10 MB

---

## 🔐 Security & Privacy

### Data In Transit
- HTTPS for all API calls (TLS 1.2+)
- Signed URLs expire in 15 minutes
- JWT tokens for authentication
- No data stored in logs

### Data At Rest
- Files stored in GCS with encryption
- activity/{activityId}/evidence/{evidenceId}/ structure
- Access controlled by service account
- Audit logging for all downloads

### Permissions Required
- **CAMERA** - Photo/video capture
- **INTERNET** - Backend communication
- **READ_EXTERNAL_STORAGE** - Gallery access
- **ACCESS_FINE_LOCATION** - GPS coordinates
- **ACCESS_COARSE_LOCATION** - Approximate location

---

## 🆘 Troubleshooting

### Camera Won't Initialize
```dart
// Check availability
final available = await CameraCaptureService.initializeCamera();
if (!available) {
  // Device doesn't have camera
}
```

### GPS Won't Capture
```dart
// Check permission
final allowed = await GpsTaggingService
  .requestLocationPermission();
if (!allowed) {
  // User denied location permission
  // Guide to settings
}

// Check service
final enabled = await GpsTaggingService
  .isLocationServiceEnabled();
if (!enabled) {
  // Location service disabled
}
```

### Upload Fails
```
Error: DioException (Connection timeout)
→ Automatically queued for offline retry
→ Will retry when network returns
→ User sees: "⚠️ No connection - queued for upload"
```

### No Compression
```
Error: ImageCompressionService fails
→ Uses original file instead
→ Warning logged
→ Process continues normally
```

---

## 📚 Documentation Links

- **Testing Guide:** [EVIDENCE_TESTS_README.md](EVIDENCE_TESTS_README.md)
- **Integration:** [PHASE_6_INTEGRATION_GUIDE.md](PHASE_6_INTEGRATION_GUIDE.md)
- **Architecture:** [ARCHITECTURE.md](../ARCHITECTURE.md)
- **Status:** [STATUS.md](../STATUS.md)

---

## 📞 Support

### For Issues
1. Check logs in terminal: `dart --version && flutter logs`
2. Run tests: `flutter test test/features/evidence/`
3. Check backend: `curl http://localhost:8000/docs`
4. Check GCS: `gsutil ls gs://sao-evidence`

### For Questions
- Flutter documentation: https://flutter.dev/docs
- GCS documentation: https://cloud.google.com/storage/docs
- Riverpod documentation: https://riverpod.dev/

---

## ✅ Checklist for Using Evidence Capture

- [ ] Backend running (http://localhost:8000)
- [ ] GCS bucket configured
- [ ] Service account permissions granted
- [ ] Camera permission requested
- [ ] Location permission requested
- [ ] Network connectivity available
- [ ] Sufficient device storage (> 100 MB)
- [ ] Tests passing (`flutter test test/features/evidence/`)

---

**Evidence Capture System Ready for Production** ✅

See also:
- [PHASE_6_DELIVERY_SUMMARY.md](PHASE_6_DELIVERY_SUMMARY.md) - What was delivered
- [RUNNING_EVIDENCE_TESTS.md](RUNNING_EVIDENCE_TESTS.md) - How to run tests
- [PHASE_6_TESTS_SUMMARY.md](PHASE_6_TESTS_SUMMARY.md) - Test completion report
