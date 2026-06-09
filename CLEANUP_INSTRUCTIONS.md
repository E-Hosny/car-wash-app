# تعليمات إعادة توليد الملفات بعد التنظيف

تم حذف الملفات المؤقتة التالية لتحرير مساحة القرص:
- ✅ مجلد `build/` (1.1GB)
- ✅ مجلد `.dart_tool/` (413MB)
- ✅ مجلد `ios/Pods/` (233MB)
- ✅ ملفات مؤقتة أخرى

## لإعادة بناء التطبيق ورفعه على App Store Connect:

### 1. إعادة تثبيت Pods (مطلوب لـ iOS):
```bash
cd ios
pod install
cd ..
```

### 2. تنظيف Flutter (اختياري):
```bash
flutter clean
```

### 3. الحصول على التبعيات:
```bash
flutter pub get
```

### 4. بناء التطبيق لـ iOS:
```bash
flutter build ios --release
```

### 5. رفع التطبيق على App Store Connect:
- افتح Xcode
- افتح `ios/Runner.xcworkspace` (ليس .xcodeproj)
- اختر Product > Archive
- ارفع الأرشيف على App Store Connect

## ملاحظات:
- جميع الملفات المحذوفة يمكن إعادة توليدها تلقائياً
- لا حاجة لحفظ هذه الملفات في Git
- يمكن إعادة بناء التطبيق في أي وقت
