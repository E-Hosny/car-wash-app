# تعليمات بناء ملف AAB

## المشكلة الحالية
يبدو أن هناك مشكلة في الوصول إلى Flutter من خلال Terminal. إليك الحلول:

## الحلول المتاحة

### الحل الأول: تشغيل ملف Batch مباشرة
1. افتح **File Explorer**
2. انتقل إلى مجلد المشروع: `C:\car_wash_app`
3. انقر مرتين على الملف: **`build_aab_detailed.bat`**
4. انتظر حتى يكتمل البناء

### الحل الثاني: تشغيل PowerShell
1. اضغط **Win + R**
2. اكتب: `powershell`
3. اضغط **Enter**
4. انتقل إلى مجلد المشروع:
   ```powershell
   cd C:\car_wash_app
   ```
5. شغل الملف:
   ```powershell
   .\build_aab_detailed.ps1
   ```

### الحل الثالث: تشغيل الأوامر يدوياً
1. افتح **Command Prompt** أو **PowerShell**
2. انتقل إلى مجلد المشروع:
   ```bash
   cd C:\car_wash_app
   ```
3. شغل الأوامر واحداً تلو الآخر:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

## التحقق من Flutter

### قبل البناء، تأكد من:
1. **Flutter مثبت** على جهازك
2. **Flutter في PATH**
3. **Android SDK مثبت**

### للتحقق من Flutter:
```bash
flutter --version
flutter doctor
```

## إذا لم يكن Flutter مثبتاً

### تثبيت Flutter:
1. اذهب إلى: https://flutter.dev/docs/get-started/install/windows
2. حمل Flutter SDK
3. استخرج الملف في: `C:\flutter`
4. أضف `C:\flutter\bin` إلى PATH
5. أعد تشغيل Command Prompt

### تثبيت Android Studio:
1. حمل Android Studio من: https://developer.android.com/studio
2. ثبت Android SDK
3. شغل: `flutter doctor --android-licenses`

## الملفات المُعدة

### ملفات البناء:
- **`build_aab_detailed.bat`** - ملف Batch مفصل
- **`build_aab_detailed.ps1`** - ملف PowerShell مفصل
- **`build_aab.bat`** - ملف Batch بسيط
- **`build_aab.ps1`** - ملف PowerShell بسيط

### ملفات التوثيق:
- **`BUILD_AAB_GUIDE.md`** - دليل شامل
- **`BUILD_INSTRUCTIONS.md`** - هذه التعليمات

## النتيجة المتوقعة

### عند نجاح البناء:
```
✅ AAB file created successfully!
📁 File location: build/app/outputs/bundle/release/app-release.aab
📊 File size: XX.XX MB
Version: 1.0.6+8
Ready for Google Play upload!
```

### موقع الملف الناتج:
```
C:\car_wash_app\build\app\outputs\bundle\release\app-release.aab
```

## استكشاف الأخطاء

### إذا فشل البناء:
1. تأكد من وجود `android/key.properties`
2. تأكد من صحة كلمات مرور التوقيع
3. تأكد من وجود ملف keystore
4. تأكد من تثبيت Android SDK

### رسائل الخطأ الشائعة:
- **"Flutter is not installed"** → ثبت Flutter
- **"Android licenses not accepted"** → شغل `flutter doctor --android-licenses`
- **"Signing failed"** → تحقق من `key.properties`

## الخطوات التالية

### بعد نجاح البناء:
1. اذهب إلى: https://play.google.com/console
2. اختر تطبيق Car Wash
3. اذهب إلى: Production → Create new release
4. ارفع ملف `app-release.aab`
5. أضف ملاحظات الإصدار
6. ابدأ المراجعة

## ملاحظات الإصدار المقترحة
```
الإصدار 1.0.6

🔧 إصلاحات:
- إصلاح مشكلة Package Toggle
- تحسين حساب الأسعار
- معالجة أفضل للأخطاء

🎨 تحسينات:
- إعادة ترتيب واجهة الطلبات
- تحسين عرض البانر
- تجربة مستخدم محسنة

⚡ استقرار:
- تحسين الأداء العام
- معالجة أفضل للأخطاء
- استقرار النظام

🆕 جديد:
- تحسينات إضافية في واجهة المستخدم
- معالجة أفضل للأخطاء
- استقرار محسن
```

## الدعم

### إذا استمرت المشكلة:
1. تأكد من أن Flutter مثبت بشكل صحيح
2. تأكد من إعدادات Android SDK
3. تأكد من وجود ملفات التوقيع
4. جرب تشغيل `flutter doctor` للتحقق من الإعدادات

**جرب الحل الأول أولاً (تشغيل ملف Batch مباشرة) فهو الأسهل! 🚀** 