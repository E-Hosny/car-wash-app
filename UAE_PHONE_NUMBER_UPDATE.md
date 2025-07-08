# تحديث إدخال رقم الهاتف للعمل في الإمارات

## التعديلات المطبقة

### 1. تحديث دالة `normalizePhone` وإضافة `isValidUAEPhone`

تم تحديث دالة `normalizePhone` وإضافة دالة `isValidUAEPhone` في الملفات التالية:
- `car_wash_app/lib/login_screen.dart`
- `car_wash_app/lib/register_screen.dart`
- `car_wash_app/lib/otp_screen.dart`
- `car_wash_provider/lib/screens/login_screen.dart`
- `car_wash_provider/lib/screens/register_screen.dart`

#### التغييرات:
- **الكود الإماراتي (+971)**: افتراضي ومطلوب للمستخدمين في الإمارات
- **الكود السعودي (+966)**: مسموح للتجربة من السعودية (بدون عرض على الشاشة)
- **إضافة validation**: التحقق من صحة تنسيق الرقم قبل الإرسال
- **تحسين التعرف على الأرقام**: إضافة فحص طول الرقم للتأكد من صحة التنسيق

### 2. إضافة Validation إجباري

#### دالة `isValidUAEPhone`:
- تتحقق من صحة تنسيق الرقم الإماراتي
- تدعم الأرقام السعودية للتجربة (بدون عرض)
- ترفض الأرقام غير الصحيحة مع رسالة خطأ واضحة

#### رسائل الخطأ:
- "Phone number is required" - إذا كان الحقل فارغ
- "Please enter a valid UAE phone number (e.g., 5XXXXXXXX)" - إذا كان التنسيق غير صحيح

### 3. تحديث واجهة المستخدم

#### شاشة تسجيل الدخول (`login_screen.dart`):
- تغيير النص إلى "Enter your UAE phone number (must start with 971 or 5XXXXXXXX)"
- تحديث `labelText` إلى "UAE Phone Number (+971)"
- إضافة `hintText` "5XXXXXXXX"
- **إضافة validation إجباري**

#### شاشة التسجيل (`register_screen.dart`):
- تحديث `labelText` إلى "UAE Phone Number (+971)"
- إضافة `hintText` "5XXXXXXXX"
- **إضافة validation إجباري**

#### تطبيق المزود:
- تحديث `labelText` في شاشات تسجيل الدخول والتسجيل إلى "UAE Phone Number (+971)"
- **إضافة validation إجباري**

### 4. صيغ الإدخال المدعومة

#### للإمارات (+971) - مطلوب:
- `5XXXXXXXX` (رقم محمول)
- `05XXXXXXXX` (رقم محمول مع صفر)
- `0XXXXXXXX` (رقم أرضي)
- `9715XXXXXXXX` (مع الكود الدولي)

#### للسعودية (+966) - للتجربة (بدون عرض):
- `9665XXXXXXXX` (مع الكود الدولي)
- `5XXXXXXXX` (سيتم إضافة 966 تلقائياً)
- `05XXXXXXXX` (سيتم إضافة 966 تلقائياً)

### 5. إرسال OTP عبر الواتساب

يتم إرسال رمز التحقق عبر الواتساب باستخدام webhook:
```dart
final webhookUrl = Uri.parse('https://www.uchat.com.au/api/iwh/7c12fdd537dcf07c2df40f2e230ed94b');
```

## كيفية الاستخدام

### للمستخدمين في الإمارات:
1. **أدخل رقم الهاتف بصيغة: `5XXXXXXXX`**
2. **النظام سيتحقق من صحة التنسيق**
3. **إذا كان التنسيق صحيح، سيتم إضافة الكود الدولي (+971) تلقائياً**
4. **ستتلقى رمز التحقق عبر الواتساب**

### للتجربة من السعودية:
1. **أدخل رقم الهاتف بصيغة: `9665XXXXXXXX`**
2. **أو أدخل: `5XXXXXXXX` وسيتم إضافة 966 تلقائياً**
3. **النظام سيقبل الرقم (بدون عرض الكود السعودي على الشاشة)**
4. **ستتلقى رمز التحقق عبر الواتساب**

## الملفات المحدثة

1. `car_wash_app/lib/login_screen.dart`
2. `car_wash_app/lib/register_screen.dart`
3. `car_wash_app/lib/otp_screen.dart`
4. `car_wash_provider/lib/screens/login_screen.dart`
5. `car_wash_provider/lib/screens/register_screen.dart`

## ملاحظات مهمة

- **الواجهة تعرض الكود الإماراتي (+971) فقط للمستخدمين**
- **النظام يتحقق من صحة تنسيق الرقم قبل الإرسال**
- **النظام يدعم الكود السعودي (+966) للتجربة من السعودية (بدون عرض)**
- **يتم إرسال OTP عبر الواتساب تلقائياً**
- **جميع الأرقام يتم تنسيقها تلقائياً قبل الإرسال إلى API**
- **رسائل خطأ واضحة ومفيدة للمستخدم** 