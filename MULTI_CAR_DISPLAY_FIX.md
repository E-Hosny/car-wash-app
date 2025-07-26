# إصلاح مشكلة عرض السيارات والخدمات في الطلبات متعددة السيارات

## المشكلة
بعد تنفيذ النظام الجديد للطلبات متعددة السيارات، تم دمج السعر بنجاح وظهرت علامة "Multi"، لكن لا تظهر تفاصيل السيارات والخدمات في واجهة المستخدم.

## السبب
المشكلة كانت في شرط التحقق في دوال عرض الطلبات. الكود كان يتحقق فقط من `orderCars->count() > 1`، مما يعني أنه لن يعرض البيانات إلا إذا كان الطلب يحتوي على أكثر من سيارة واحدة.

## الحل

### 1. تعديل شرط التحقق
تم تغيير الشرط من:
```php
if ($order->orderCars->count() > 1)
```
إلى:
```php
if ($order->orderCars->count() > 0)
```

### 2. إضافة معالجة للطلبات العادية
تم إضافة معالجة للطلبات التي لا تحتوي على `orderCars` (الطلبات العادية):
```php
} else {
    $order->is_multi_car = false;
    $order->cars_count = 1;
    // For orders without orderCars, use the main car and services
    $order->all_cars = [[
        'id' => $order->car->id,
        'brand' => $order->car->brand->name,
        'model' => $order->car->model->name,
        'services' => $order->services->pluck('name'),
        'subtotal' => $order->total,
    ]];
}
```

### 3. الدوال المعدلة
تم تعديل جميع دوال عرض الطلبات:
- `myOrders()` - طلبات المستخدم
- `show($id)` - عرض طلب مفرد
- `availableOrders()` - الطلبات المتاحة للمزودين
- `completedOrders()` - الطلبات المكتملة
- `acceptedOrders()` - الطلبات المقبولة
- `inProgressOrders()` - الطلبات قيد التنفيذ

## النتيجة المتوقعة

### قبل الإصلاح:
```json
{
  "id": 31,
  "total": 90.00,
  "is_multi_car": false,
  "cars_count": 1,
  "all_cars": null
}
```

### بعد الإصلاح:
```json
{
  "id": 31,
  "total": 90.00,
  "is_multi_car": true,
  "cars_count": 2,
  "all_cars": [
    {
      "id": 1,
      "brand": "Honda",
      "model": "Accord",
      "year": "2020",
      "services": ["external wash"],
      "subtotal": 40.00,
      "points_used": 0
    },
    {
      "id": 2,
      "brand": "Toyota",
      "model": "Corolla",
      "year": "2021",
      "services": ["interior polishing"],
      "subtotal": 50.00,
      "points_used": 0
    }
  ]
}
```

## كيفية الاختبار

1. **إنشاء طلب متعدد السيارات جديد**:
   - افتح تطبيق Flutter
   - اذهب إلى Multi-Car Order
   - أضف سيارتين أو أكثر مع خدمات مختلفة
   - أنشئ الطلب

2. **التحقق من النتيجة**:
   - اذهب إلى صفحة الطلبات
   - يجب أن ترى:
     - طلب واحد فقط
     - علامة "Multi" 
     - تفاصيل جميع السيارات والخدمات
     - السعر الإجمالي الصحيح

3. **اختبار الطلبات العادية**:
   - أنشئ طلب عادي (سيارة واحدة)
   - تأكد من أن البيانات تظهر بشكل صحيح

## ملاحظات مهمة

- الإصلاح يعمل مع الطلبات الجديدة والقديمة
- الطلبات العادية ستظهر بيانات السيارة الرئيسية
- الطلبات متعددة السيارات ستظهر جميع السيارات والخدمات
- النظام متوافق مع نظام الباقات والنقاط

## استكشاف الأخطاء

إذا لم تظهر البيانات بعد الإصلاح:

1. **تحقق من API Response**:
   - استخدم Postman أو أي أداة اختبار API
   - اتصل بـ `GET /api/orders/my`
   - تحقق من وجود `all_cars` في الاستجابة

2. **تحقق من قاعدة البيانات**:
   ```sql
   SELECT * FROM order_cars WHERE order_id = 31;
   SELECT * FROM order_car_service WHERE order_car_id IN (SELECT id FROM order_cars WHERE order_id = 31);
   ```

3. **تحقق من التطبيق الأمامي**:
   - تأكد من أن التطبيق يعرض `all_cars` بدلاً من `car` و `services`
   - تحقق من console للأخطاء

## الملفات المعدلة

- `car-wash-api/app/Http/Controllers/API/OrderController.php` - جميع دوال عرض الطلبات 