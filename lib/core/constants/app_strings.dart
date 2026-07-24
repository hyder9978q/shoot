import '../utils/arabic_num.dart';

/// نصوص التطبيق — لهجة عراقية بسيطة وواضحة
/// كل النصوص بمكان واحد حتى يسهل تعديلها لاحقاً
class AppStrings {
  AppStrings._();

  static const String appName = 'شوت';
  static const String slogan = 'شوت... واحجز ملعبك.';

  // تسجيل الدخول
  static const String loginTitle = 'هلا بيك بشوت 👋';
  static const String loginSubtitle = 'دخّل رقم موبايلك ونرسلك رمز التحقق';
  static const String phoneLabel = 'رقم الموبايل';
  static const String phoneHint = '07XX XXX XXXX';
  static const String phoneError = 'الرقم لازم يبدي بـ 07 ويكون 11 رقم';
  static const String sendCode = 'دزلي الرمز';
  static const String termsNote =
      'بالدخول انت توافق على شروط الاستخدام وسياسة الخصوصية';
  static const String versionLine = 'النسخة ١.٠ · العراق';
  static const String otpSendError =
      'ما گدرنا ندز الرمز 😕 تأكد من الإنترنت وجرّب مرة ثانية';
  static const String phoneAuthDisabled =
      'تسجيل الدخول بالهاتف بعده مو مفعّل بإعدادات Firebase';
  static const String tooManyRequests = 'محاولات هواي! انتظر شوية وجرّب بعدين';
  static const String realSmsNeedsBilling =
      'الرسائل الحقيقية بعدها مقفلة — استخدم رقم التجربة 07701234567';

  // رمز التحقق
  static const String otpTitle = 'دخّل رمز التحقق';
  static const String otpSubtitle = 'دزينا رمز من 6 أرقام على الرقم:';
  static const String otpError = 'الرمز غلط، جرّب مرة ثانية';
  static const String otpDevHint =
      'للتجربة هسه: الرمز هو 123456\n(بعدين يوصلك SMS حقيقي)';
  static const String resendCode = 'ما وصلك؟ دزلي مرة ثانية';
  static const String resendIn = 'إعادة الإرسال خلال';
  static const String codeSentAgain = 'دزيناه من جديد ✅';
  static const String confirm = 'تأكيد';
  static const String changeNumber = 'غيّر الرقم';

  // شاشة الاسم (أول تسجيل)
  static const String nameTitle = 'شنو نسميك؟ 😊';
  static const String nameSubtitle = 'اكتب اسمك أو لقبك حتى نناديك بيه';
  static const String nameHint = 'اسمك';
  static const String nameStart = 'يلا نبدي';
  static const String nameSkip = 'بعدين';

  // الرئيسية
  /// تحية قصيرة فوق اسم المدينة برأس الصفحة
  static const String homeHello = 'هلا بيك 👋';
  static String homeHelloNamed(String name) => 'هلا بيك، $name 👋';

  static const String allFieldsTitle = 'كل الأماكن';
  static const String resultsTitle = 'نتائج البحث';
  static const String fieldWord = 'مكان';
  static const String clearFilters = 'شيل الفلاتر';

  // بانر اللعبة
  static const String gameEyebrow = 'لعبة شوت';
  static const String gameHeadline = 'جرّب حظك بضربات الترجيح';
  static const String gameCta = 'العب هسه';

  // الخريطة
  static const String mapTitle = 'خريطة الملاعب';
  static const String allIraq = 'كل العراق';
  static const String viewAndBook = 'شوف واحجز';
  static const String directionsLabel = 'الاتجاهات';

  // قسم العب اليوم
  static const String playTodayTitle = 'العب اليوم';
  static const String playTodaySubtitle = 'أقرب وقت فاضي بكل ملعب';
  static const String freeAtLabel = 'فاضي';
  static const String searchHint = 'دوّر على ملعب، مسبح، مركز...';
  static const String allSports = 'الكل';
  static const String noResults = 'ماكو ملاعب بهذا البحث 😕\nجرّب كلمة ثانية';
  static const String perHour = 'للساعة';
  static const String perHourShort = 'د.ع/س';

  /// مكان بعده ما مسجّل بالتطبيق — ما عدنا سعره
  static const String priceOnCall = 'اتصل للسعر';
  static const String reviewWord = 'تقييم';
  static const String logout = 'تسجيل خروج';

  // تفاصيل الملعب والحجز
  static const String todaySlotsTitle = 'اختار اليوم والوقت';
  static const String sendWhatsappConfirm = 'دز التأكيد على الواتساب';
  static const String bookedLabel = 'محجوز';
  static const String bookNow = 'احجز هسه';
  static const String pickTimeFirst = 'اختار وقت أول';
  static const String confirmBookingTitle = 'تأكيد الحجز';
  static const String depositLabel = 'العربون';
  static const String depositNote =
      'الدفع الإلكتروني بعده ما مفعّل — العربون يتأكد بالملعب.\n(زين كاش والبطاقة تنضاف قريباً)';
  static const String payDeposit = 'ادفع العربون';

  // شاشة تأكيد الحجز والدفع
  static const String bookingSummary = 'ملخص الحجز';
  static const String fieldLabel = 'الملعب';
  static const String dateTimeLabel = 'التاريخ والوقت';
  static const String hourPriceLabel = 'السعر (ساعة)';
  static const String depositNow = 'العربون المطلوب الآن';
  static String restAtField(String rest) => 'الباقي ($rest) يُدفع بالملعب';
  static const String payMethodTitle = 'طريقة الدفع';
  static const String zainCash = 'زين كاش';
  static const String zainCashHint = 'الأكثر استخداماً بالعراق';
  static const String cardPay = 'بطاقة ماستر/فيزا';
  static const String cardPayHint = 'أضف بطاقة جديدة';
  static const String cancel = 'إلغاء';
  static const String bookingSuccessTitle = 'تم الحجز ✅';
  static String bookingSuccessSub(String field) =>
      'حجزك بـ$field تم بنجاح.\nنشوفك بالملعب 🎉';
  static const String bookingSuccessNote =
      'راح يوصلك تأكيد واتساب من نفعّل الإشعارات.\nلا تنسى: الباقي كاش بالملعب.';
  // الملف الشخصي — بطاقات الأرقام
  static const String bookingWord = 'حجز';
  static const String favoritesWord = 'مفضلة';
  static const String reviewsWord = 'تقييم';
  static const String newBadge = 'جديد';
  static const String guestName = 'ضيف';

  // تبويب حجوزاتي
  static const String upcomingTab = 'القادمة';
  static const String pastTab = 'السابقة';
  static const String doneLabel = 'منتهي';
  static const String detailsAction = 'التفاصيل';
  static const String fieldNotFound = 'ما لكينا الملعب';
  static const String noPastBookings = 'ماكو حجوزات سابقة';

  static const String ticketTitle = 'تذكرة الحجز';
  static const String ticketSportLabel = 'النوع';
  static const String dateLabel = 'التاريخ';
  static const String timeLabel = 'الوقت';
  static const String paidDeposit = 'مدفوع (عربون)';
  static const String backHome = 'ارجع للرئيسية';
  static const String iqd = 'د.ع';
  static const String slotTakenError =
      'عذراً، هذا الوقت توه انحجز من شخص ثاني 😕 اختار وقت غيره';
  static const String bookingError =
      'ما گدرنا نسجّل الحجز 😕 تأكد من الإنترنت وجرّب مرة ثانية';

  // حجوزاتي
  static const String myBookingsTitle = 'حجوزاتي';
  static const String noBookingsTitle = 'بعدك ما عندك حجوزات';
  static const String noBookingsMessage =
      'من تحجز ملعب، حجزك راح يظهر هنا\nمع وقته وتفاصيله';
  static const String browseFields = 'تصفّح الملاعب';
  static const String noPastBookingsMessage =
      'ماكو حجوزات خلصت بعد.\nاحجز ملعب واستمتع بلعبتك!';
  static const String confirmedLabel = 'مؤكد';
  static const String todayLabel = 'اليوم';
  static const String cancelBookingTitle = 'إلغاء الحجز';
  static const String cancelBookingConfirm =
      'متأكد تريد تلغي الحجز؟\nالوقت راح يرجع متاح للكل.';
  static const String keepBooking = 'لا، خليه';
  static const String yesCancel = 'إي، الغيه';
  static const String bookingCancelled = 'انلغى الحجز ✅';
  static const String bookingsLoadError =
      'ما گدرنا نجيب حجوزاتك 😕 اسحب للأسفل للتحديث';

  // ناقصنا لاعب
  static const String playersTitle = 'ناقصنا لاعب';
  static const String playersSubtitle =
      'فريقك ناقص؟ انشر إعلان — أو انضم لفريق يدوّر لاعب';
  static const String postRequest = 'انشر إعلان';
  static const String noRequestsTitle = 'ماكو إعلانات اليوم';
  static const String noRequestsMessage =
      'كون أول واحد ينشر!\nفريقك ناقص لاعب؟ انشر إعلان وخلي اللاعبين يجونك';
  static const String requestsLoadError =
      'ما گدرنا نجيب الإعلانات 😕 اسحب للأسفل للتحديث';
  static const String myRequestBadge = 'إعلانك';
  static const String whatsappContact = 'واتساب';
  static const String callContact = 'اتصال';
  static const String whatsappMessage =
      'هلا، شفت إعلانكم بتطبيق شوت — أريد ألعب وياكم ⚽';
  static const String deleteRequestTitle = 'حذف الإعلان';
  static const String deleteRequestConfirm =
      'اكتمل فريقك؟ عاش!\nنحذف الإعلان حتى ما يتصلون بيك بعد.';
  static const String keepRequest = 'لا، خليه';
  static const String yesDelete = 'إي، احذفه';
  static const String requestDeleted = 'انحذف الإعلان ✅';
  static const String requestPosted = 'انتشر إعلانك ✅ من يتصلون بيك، رد عليهم!';
  static const String requestPostError =
      'ما گدرنا ننشر الإعلان 😕 تأكد من الإنترنت وجرّب مرة ثانية';

  // نموذج نشر الإعلان
  static const String newRequestTitle = 'انشر إعلان — ناقصنا لاعب';
  static const String sportLabel = 'شنو الرياضة؟';
  static const String placeLabel = 'وين اللعبة؟';
  static const String placeHint = 'مثال: ملعب النجوم — المنصور';
  static const String placeError = 'اكتب مكان اللعبة';
  static const String timeLabel2 = 'أي ساعة اليوم؟';
  static const String timeError = 'اختار وقت اللعبة';
  static const String playersNeededLabel = 'چم لاعب ناقصكم؟';
  static const String playersUnit = 'لاعب';
  static const String noteLabel = 'ملاحظة (اختياري)';
  static const String noteHint = 'مثال: المستوى وسط، اللعبة ودّية';
  static const String contactNote =
      'رقمك راح يظهر بالإعلان حتى اللاعبين يتواصلون وياك';

  // صفحة الملعب: الوصف والمرافق والتقييمات
  static const String aboutFieldTitle = 'عن الملعب';
  static const String amenitiesTitle = 'المرافق';
  static const String reviewsTitle = 'التقييمات';
  static const String rateField = 'قيّم الملعب';
  static const String editMyReview = 'عدّل تقييمك';
  static const String reviewCommentHint = 'شلون كانت تجربتك؟ (اختياري)';
  static const String submitReview = 'انشر التقييم';
  static const String reviewSaved = 'تم حفظ تقييمك ⭐ شكراً!';
  static const String reviewError = 'ما گدرنا نحفظ التقييم 😕 جرّب مرة ثانية';
  static const String noReviewsYet =
      'بعد ماكو تقييمات — كن أول واحد يقيّم هذا الملعب!';
  static const String myReviewsTitle = 'تقييماتي';
  static const String noMyReviewsTitle = 'بعدك ما قيّمت أي ملعب';
  static const String noMyReviewsMessage =
      'من تلعب بملعب، ارجع لصفحته وقيّمه ⭐\nتقييمك يساعد اللاعبين الباقين';
  static const String deleteReviewTitle = 'حذف التقييم';
  static const String deleteReviewConfirm = 'متأكد تريد تحذف تقييمك؟';
  static const String reviewDeleted = 'انحذف التقييم';

  // المفضلة
  static const String favoritesTitle = 'المفضلة';
  static const String favoritesCountUnit = 'ملعب محفوظ';
  static const String noFavoritesTitle = 'بعدك ماكو مفضلة';
  static const String noFavoritesMessage =
      'اضغط على القلب ❤️ بأي ملعب يعجبك\nحتى يظهر هنا ويصير حجزه أسرع';

  // لوحة صاحب الملعب
  static const String ownerDashboard = 'لوحة صاحب الملعب';
  static const String ownerWelcome = 'مرحباً';
  static String ownerFieldsCount(String count) => '$count ملاعب';
  static const String todayEarnings = 'أرباح اليوم';
  static const String todayBookings = 'حجوزات اليوم';
  static String freeSlotsCount(String count) => '$count وقت فاضي';
  static const String weekEarnings = 'أرباح الأسبوع';
  static String ownerSlotsForDay(String dayLabel) => 'أوقات $dayLabel';
  static const String bookingsCountLabel = 'حجز اليوم';
  static const String depositsLabel = 'عرابين اليوم';
  static const String freeLabel = 'فاضي';
  static const String ownerHint =
      'الأوقات الخضراء محجوزة ومدفوع عربونها.\nتريد تسد وقت لصيانة أو زبون حجز عن طريق التلفون؟ استخدم "حجز يدوي".';

  // الحجز اليدوي (لصاحب الملعب) — زبون حجز خارج التطبيق
  static const String manualBookingAction = 'حجز يدوي';
  static const String manualBookingTitle = 'حجز يدوي';
  static const String manualBookingSubtitle =
      'لزبون حجز عن طريق التلفون أو الواتساب أو حضر مباشرة';
  static const String manualBookingFieldLabel = 'اختار الملعب';
  static const String manualBookingDateLabel = 'اختار اليوم';
  static const String manualBookingTimeLabel = 'اختار الوقت';
  static const String manualBookingNoSlots = 'ماكو أوقات فاضية هذا اليوم';
  static const String manualBookingCustomerNameLabel = 'اسم الزبون';
  static const String manualBookingCustomerNameHint = 'مثال: أبو أحمد';
  static const String manualBookingCustomerPhoneLabel = 'رقم الزبون (اختياري)';
  static const String manualBookingCustomerPhoneHint = '07XX XXX XXXX';
  static const String manualBookingNoteLabel = 'ملاحظة (اختياري)';
  static const String manualBookingNoteHint = 'مثال: يدفع كاش بالملعب';
  static const String manualBookingConfirm = 'سجّل الحجز';
  static const String manualBookingPickTimeFirst = 'اختار وقت أول';
  static const String manualBookingNameRequired = 'اسم الزبون مطلوب';
  static const String manualBookingSuccess = 'انسجّل الحجز اليدوي ✅';
  static const String manualBookingError =
      'ما گدرنا نسجّل الحجز 😕 تأكد من الإنترنت وجرّب مرة ثانية';
  static const String manualBadge = 'يدوي';
  static const String manualBookedBy = 'حجز يدوي';
  static const String deleteManualBookingTitle = 'حذف الحجز اليدوي';
  static const String deleteManualBookingConfirm =
      'متأكد تريد تحذف هذا الحجز اليدوي؟ الوقت يرجع فاضي.';
  static const String manualBookingDeleted = 'انحذف الحجز اليدوي ✅';
  static const String manualBookingDeleteError =
      'ما گدرنا نحذف الحجز، جرّب مرة ثانية';

  // إدارة صور الملعب (لصاحب الملعب)
  static const String fieldPhotosTitle = 'صور الملعب';
  static const String managePhotosAction = 'إدارة الصور';
  static const String addPhotosButton = 'أضف صور';
  static const String uploadingPhotos = 'نرفع الصور... لحظة';
  static const String noFieldPhotosTitle = 'ماكو صور بعد';
  static const String noFieldPhotosMessage =
      'أضف صور حقيقية لملعبك — الصور الحلوة تزيد الحجوزات هواي!\nتگدر ترفع أكثر من صورة سوة.';
  static const String photosCountLabel = 'صورة';
  static const String coverPhotoBadge = 'الغلاف';
  static const String photoUploadedOk = 'انرفعت الصور ✅';
  static const String photoUploadError =
      'ما گدرنا نرفع الصور 😕 تأكد من الإنترنت وجرّب مرة ثانية';
  static const String deletePhotoTitle = 'حذف الصورة';
  static const String deletePhotoConfirm = 'متأكد تريد تحذف هالصورة؟';
  static const String photoDeleted = 'انحذفت الصورة ✅';
  static const String photoDeleteError =
      'ما گدرنا نحذف الصورة 😕 جرّب مرة ثانية';
  static const String photosNeedLiveApp =
      'رفع الصور يشتغل بالتطبيق المنشور فقط — مو بوضع التجربة المحلي.';
  static const String photoInvalidType =
      'نقبل صور فقط (jpg, jpeg, png, webp) — الملف اللي اخترته مو صورة';
  static const String photoTooLarge =
      'حجم الصورة أكبر من ٥ ميغابايت — صغّرها وجرّب مرة ثانية';

  // إدارة الملعب (لصاحب الملعب)
  static const String manageFieldAction = 'إدارة الملعب';
  static const String manageFieldTitle = 'إدارة الملعب';
  static const String basicInfoSection = 'المعلومات الأساسية';
  static const String fieldNameLabel = 'اسم الملعب';
  static const String fieldNameError = 'اكتب اسم الملعب';
  static const String areaLabel = 'المنطقة';
  static const String areaError = 'اكتب المنطقة';
  static const String cityLabel = 'المدينة';
  static const String cityError = 'اكتب المدينة';
  static const String priceLabel = 'سعر الساعة (د.ع)';
  static const String priceError = 'دخّل سعر صحيح (0 لحد مليون)';
  static const String sportTypeLabel = 'نوع الرياضة';
  static const String workingHoursLabel = 'ساعات الدوام';
  static const String opensAtLabel = 'يفتح';
  static const String closesAtLabel = 'يسد';
  static const String hoursError = 'وقت الفتح لازم يكون قبل وقت السد';
  static const String fieldStatusLabel = 'حالة الملعب';
  static const String fieldOpenLabel = 'مفتوح — يستقبل حجوزات';
  static const String fieldClosedLabel = 'مغلق مؤقتاً — ماكو حجوزات';
  static const String fieldClosedBadge = 'مغلق مؤقتاً';
  static const String saveInfoButton = 'احفظ التعديلات';
  static const String infoSaved = 'انحفظت التعديلات ✅';
  static const String infoSaveError =
      'ما گدرنا نحفظ 😕 تأكد من الإنترنت وجرّب مرة ثانية';

  // الوسائط (لصاحب الملعب)
  static const String mediaSection = 'الوسائط';
  static const String mapsLinkLabel = 'رابط الموقع (خرائط گوگل)';
  static const String mapsLinkHint = 'https://maps.app.goo.gl/...';
  static const String mapsLinkError = 'الرابط لازم يبدي بـ https';
  static const String mapsLinkSaved = 'انحفظ رابط الموقع ✅';
  static const String promoSection = 'الصور الترويجية';
  static const String promoHint =
      'صور عروضك وإعلاناتك — تظهر كبانر بصفحة الملعب';
  static const String addPromoButton = 'أضف صورة ترويجية';
  static const String highlightsSection = 'لقطات الملعب';
  static const String highlightsHint =
      'أحلى اللقطات من مباريات ملعبك — صور أو روابط فيديو';
  static const String addHighlightPhoto = 'أضف صورة';
  static const String addHighlightVideo = 'أضف رابط فيديو';
  static const String videoLinkTitle = 'رابط الفيديو';
  static const String videoLinkHint = 'رابط يوتيوب أو انستغرام (https)';
  static const String videoLinkError =
      'الرابط لازم يكون https من يوتيوب أو انستغرام';
  static const String highlightAdded = 'انضافت اللقطة ✅';
  static const String deleteHighlightTitle = 'حذف اللقطة';
  static const String deleteHighlightConfirm = 'متأكد تريد تحذف هاللقطة؟';
  static const String videoBadge = 'فيديو';
  static const String fieldHighlightsTitle = 'لقطات الملعب';

  // طرق الدفع (لصاحب الملعب)
  static const String paymentsSection = 'طرق الدفع';
  static const String paymentsHint =
      'اختار شلون يدفعون الزبائن بملعبك — لازم تبقى طريقة وحدة على الأقل';
  static const String payDepositOption = 'عربون بالتطبيق';
  static const String payDepositDesc =
      'الزبون يدفع عربون ويكمّل الباقي بالملعب';
  static const String payCashOption = 'كاش عند الوصول';
  static const String payCashDesc = 'الزبون يدفع كامل المبلغ بالملعب';
  static const String zainCashSection = 'بوابة زين كاش';
  static const String zainCashComingSoon =
      'التفعيل الفعلي قريباً — هسه بس نحفظ إعداداتك حتى تكون جاهزة';
  static const String merchantIdLabel = 'معرّف التاجر (Merchant ID)';
  static const String merchantIdHint = 'مثال: MER-12345';
  static const String merchantIdError = 'فعّلت زين كاش؟ دخّل معرّف التاجر';
  static const String onePaymentRequired =
      'لازم تبقى طريقة دفع وحدة مفعّلة على الأقل';

  // ترتيب الصور (لصاحب الملعب)
  static const String reorderPhotosHint =
      'اسحب الصور لترتيبها — أول صورة هي الغلاف';
  static const String photosReordered = 'انحفظ الترتيب ✅';

  // المنشآت — الفئات الجديدة (مسابح ومراكز علاج)
  static const String therapyFullLabel = 'مركز علاج رياضي وطبيعي';
  static const String servicesTitle = 'الخدمات والأسعار';
  static const String sessionSlotsTitle = 'اختار موعد جلستك';
  static const String bookSession = 'احجز موعد';
  static const String sessionWord = 'جلسة';
  static const String perSessionShort = 'د.ع/جلسة';
  static const String sessionStartsFrom = 'الجلسة تبدأ من';
  static const String sessionPriceLabel = 'سعر الجلسة';
  static const String confirmNoDeposit = 'أكّد الحجز';
  static const String noDepositNote =
      'هذا المكان ما يطلب عربون — الدفع كله يصير هناك عند الوصول.';
  static const String payAtVenueLabel = 'يُدفع بالمكان';

  // إدارة الخدمات (لصاحب المنشأة)
  static const String manageServicesSection = 'الخدمات والأسعار';
  static const String manageServicesHint =
      'خدمات مركزك وأسعارها — تظهر بصفحة المركز ويختار منها الزبون';
  static const String addServiceButton = 'أضف خدمة';
  static const String serviceNameLabel = 'اسم الخدمة';
  static const String serviceNameHint = 'مثال: جلسة علاج طبيعي';
  static const String serviceNameError = 'اكتب اسم الخدمة';
  static const String servicePriceLabel = 'سعر الخدمة (د.ع)';
  static const String serviceAdded = 'انضافت الخدمة ✅';
  static const String serviceDeleted = 'انحذفت الخدمة ✅';
  static const String deleteServiceTitle = 'حذف الخدمة';
  static const String deleteServiceConfirm = 'متأكد تريد تحذف هالخدمة؟';
  static const String noServicesYet =
      'بعد ما ضفت خدمات — أضف خدمات مركزك حتى تظهر للزبائن';

  // لعبة ضربات الترجيح
  static const String gameTitle = 'ضربات الترجيح';
  static const String gameBannerSubtitle =
      'العب واجمع نقاط — وقريباً بدّلها بخصومات 🎁';
  static const String gameHint = 'اضغط على مكان بالمرمى وسدد ⚽';
  static const String gamePointsLabel = 'النقاط';
  static const String goalCall = 'گوووول! ⚽';
  static const String savedCall = 'صدّها الحارس! 🧤';
  static const String missCall = 'برا الحديدة! 😅';
  static const String gameOverTitle = 'خلصت الجولة!';
  static const String goalsLabel = 'أهداف';
  static const String bestStreakLabel = 'أحلى سلسلة';
  static const String sessionBestLabel = 'أعلى نتيجة إلك';
  static const String playAgain = 'العب مرة ثانية';
  static const String exitGame = 'رجوع';
  static const String rewardTeaser =
      'قريباً: بدّل نقاطك بخصم حقيقي على حجز الملاعب 🎁';
  static const String rating5 = 'خرافي! ما ينصد منك 🔥';
  static const String rating4 = 'عاش الله بيك! 👏';
  static const String rating3 = 'زين، بس تگدر أحسن 💪';
  static const String rating2 = 'تدرب شوية وارجع ⚽';
  static const String rating01 = 'الحارس گام يضحك 😅 جرّب مرة ثانية';

  // تفاصيل الملعب — خانات المواصفات وشريط الحجز
  static const String surfaceLabel = 'الأرضية';
  static const String sizeLabel = 'الحجم';
  static const String lightingValue = 'إنارة';
  static const String startsFrom = 'يبدأ من';

  // ---------- الإلغاء والبديل الفوري ----------

  // صاحب الملعب يلغي
  static const String ownerCancelTitle = 'تلغي حجز اللاعب؟';
  static const String ownerCancelBody =
      'راح نخبر اللاعب فوراً ونلگاله بديل بنفس الوكت. '
      'وينحسب عليك بنسبة الالتزام، فلا تلغي إلا للضرورة.';
  static const String ownerCancelReasonHint = 'شنو السبب؟ (اختياري)';
  static const String ownerCancelConfirm = 'إي، ألغي الحجز';
  static const String ownerCancelKeep = 'لا، خليه';
  static const String ownerCancelDone = 'انلغى الحجز وانخبر اللاعب ✅';
  static const String ownerCancelError = 'ما گدرنا نلغي الحجز، جرّب مرة ثانية';
  static const String ownerCancelSlotAction = 'ألغي الحجز';
  static const String ownerBookedBy = 'محجوز من لاعب';
  static const String ownerNotifyPlayer = 'خبّر اللاعب بالواتساب';
  static const String ownerCancelNoPhone =
      'ما عدنا رقم اللاعب — بلّغه بنفسك لو تگدر';

  /// رسالة الواتساب اللي يدزها صاحب الملعب للاعب
  static String ownerCancelWhatsapp({
    required String fieldName,
    required String dayLabel,
    required String time,
    required String reason,
  }) =>
      'سلام عليكم 🙏\n'
      'نعتذر منك — اضطرينا نلغي حجزك بـ$fieldName يوم $dayLabel الساعة $time.'
      '${reason.isEmpty ? '' : '\nالسبب: $reason'}\n\n'
      'فتحنا إلك بدائل بنفس الوكت بتطبيق شوت، وحجزك الجاي مضمون '
      'بدون عربون 🎁\n'
      '— اعتذارنا مرة ثانية، شوت ⚽';

  // إشعار اللاعب داخل التطبيق
  static const String cancelAlertTitle = 'انلغى حجزك 😔';
  static String cancelAlertBody(String fieldName, String dayLabel) =>
      'ملعب $fieldName ألغى حجزك يوم $dayLabel — ما عليك، لگينا إلك بدائل';
  static const String cancelAlertAction = 'شوف البدائل';
  static const String cancelAlertDismiss = 'بعدين';
  static const String cancelReasonLabel = 'السبب اللي ذكره الملعب:';

  // شاشة البدائل
  static const String replacementTitle = 'بدائل جاهزة إلك';
  static String replacementSubtitle(String dayLabel, String time) =>
      'نفس اليوم ($dayLabel) ونفس الوكت ($time) — والأقرب أول';
  static const String replacementEmpty =
      'ما لگينا بديل فاضي بنفس الوكت 😕\n'
      'جرّب وكت ثاني أو مدينة ثانية — وعربونك المضمون يضل محفوظ إلك';
  static const String replacementBrowse = 'تصفّح كل الملاعب';
  static const String bookReplacement = 'احجز البديل';
  static const String replacementLoading = 'ندوّر إلك بدائل...';
  static const String awayLabel = 'يبعد';

  // ضمان الحجز
  static const String guaranteedBadge = 'محجوز مضمون';
  static const String guaranteedNoDeposit = 'بدون عربون 🎁';
  static const String guaranteedExplain =
      'لأن حجزك السابق انلغى مو بذنبك — هذا الحجز بدون عربون';
  static const String guaranteedCreditsTitle = 'حجوزاتك المضمونة';
  static String guaranteedCreditsCount(String count) =>
      'عندك $count حجز مضمون بدون عربون';
  static const String myCancellationsTitle = 'إلغاءات مو بذنبك';
  static const String myCancellationsEmpty = 'ما عندك أي إلغاء — عاشت إيدك 👏';
  static const String notMyFaultLabel = 'إلغاء مو بذنبك';
  static const String compensatedLabel = 'استخدمت الضمان ✅';

  // نسبة الالتزام
  static const String reliabilityLabel = 'نسبة الالتزام';
  static String reliabilityValue(String percent) => '$percent٪ التزام';
  static const String reliabilityGood = 'ملعب جاد بحجوزاته ✅';
  static const String reliabilityRisky = 'ينلغي عنده أحياناً ⚠️';
  static const String reliabilityNew = 'بعده جديد — ما عده تاريخ كافي';
  static String reliabilityTooltip(String kept, String cancelled) =>
      'أكمل $kept حجز وألغى $cancelled';

  // عام
  static const String loading = 'لحظة...';
  static const String retry = 'جرّب مرة ثانية';
  static const String comingSoon = 'قريباً إن شاء الله';
  static const String pressBackAgainToExit = 'دزّ رجوع مرة ثانية للخروج من شوت';

  // ملفي وإحصائياتي
  static const String myProfileItem = 'ملفي وإحصائياتي';
  static const String playerProfileTitle = 'ملف اللاعب';
  static const String matchesPlayedWord = 'مباراة';
  static const String gapsFilledWord = 'مرة كمّل نقص';
  static const String noCityYet = 'ما حددت مدينتك بعد';
  static const String pickCity = 'اختار مدينتك';
  static const String chooseCityTitle = 'اختار مدينتك';
  static const String citySavedMsg = 'تحدّثت مدينتك ✅';
  static const String changePhoto = 'غيّر الصورة';
  static const String photoSaved = 'تحدّثت الصورة ✅';
  static const String badgesTitle = 'الشارات';
  static const String badgeLocked = 'ما حصّلتها بعد';
  static const String profileLoadError = 'ما گدرنا نجيب بيانات الملف';

  // ترتيب الحي/المدينة
  static const String leaderboardItem = 'ترتيب اللاعبين';
  static const String leaderboardTitle = 'ترتيب حيّك';
  static String leaderboardSubtitle(String city) =>
      'أنشط اللاعبين بـ$city هذا الشهر';
  static const String leaderboardNeedsCity =
      'حدد مدينتك حتى نطلعلك ترتيبك بيها';
  static const String leaderboardEmpty =
      'ما بيه لاعبين نشيطين هذا الشهر بعد — كن أول وحد 🏆';
  static String yourRank(String rank) => 'ترتيبك: #$rank';
  static const String notRankedYet = 'ما لعبت هذا الشهر بعد بهذي المدينة';

  // انضمام "ناقصنا لاعب"
  static const String joinRequest = 'أني أجي 🙋';
  static const String joinedRequest = '✓ آني جاي';
  static const String withdrawnMsg = 'سحبنا تسجيلك';
  static const String joinRequestError =
      'ما گدرنا نسجّل انضمامك، جرّب مرة ثانية';
  static const String joinRequestSuccess = 'سجّلنا إنك جاي — عاشت إيدك 👏';

  // الإعدادات
  static const String settingsTitle = 'الإعدادات';
  static const String settingsAccountSection = 'الحساب';
  static const String settingsNameLabel = 'الاسم';
  static const String settingsCityLabel = 'المدينة';
  static const String settingsPhotoLabel = 'الصورة';
  static const String settingsPhoneLabel = 'رقم الهاتف';
  static const String editNameTitle = 'عدّل اسمك';
  static const String nameSavedMsg = 'تحدّث اسمك ✅';
  static const String nameEmptyError = 'اكتب اسمك';
  static const String save = 'احفظ';

  static const String settingsAppearanceSection = 'المظهر';
  static const String settingsDarkModeLabel = 'الوضع الليلي';
  static const String settingsDarkModeHint = 'خلفية غامقة تريح العين بالليل';

  static const String settingsNotificationsSection = 'الإشعارات';
  static const String notifyBookingConfirmLabel = 'تأكيد الحجز';
  static const String notifyBookingConfirmHint =
      'إشعار لما ينحجز أو ينلغى حجزك';
  static const String notifyReminderLabel = 'تذكير قبل الموعد';
  static const String notifyReminderHint = 'تذكير قبل وكت لعبتك بشوي';
  static const String notifyPlayerRequestsLabel = 'طلبات ناقصنا لاعب';
  static const String notifyPlayerRequestsHint =
      'إشعار لما حد يريد ينضم لإعلانك';

  static const String settingsAboutSection = 'عن التطبيق والدعم';
  static const String contactSupportLabel = 'تواصل مع الدعم';
  static const String contactSupportHint = 'راسلنا بالواتساب لأي استفسار';
  static const String supportWhatsappMessage = 'هلا، أحتاج مساعدة بتطبيق شوت 🙏';
  static const String privacyPolicyLabel = 'سياسة الخصوصية';
  static const String termsOfUseLabel = 'شروط الاستخدام';
  static const String appVersionLabel = 'رقم الإصدار';
  static const String appVersionNumber = '1.0.0';

  static const String privacyPolicyTitle = 'سياسة الخصوصية';
  static const String privacyPolicyBody = '''
نحترم خصوصيتك، وهذي وياك خلاصة شنو نجمع وشلون نستخدمه:

• المعلومات اللي نجمعها: رقم هاتفك (لتسجيل الدخول برمز التحقق)، اسمك، مدينتك، صورة ملفك الشخصي (إذا رفعتها)، وبيانات حجوزاتك وتقييماتك داخل التطبيق.

• شلون نستخدمها: نستخدم بياناتك حتى نسجّل حجوزاتك، نربطك بالملاعب واللاعبين الثانين (مثلاً بترتيب الحي أو "ناقصنا لاعب")، ونحسّن خدمة التطبيق.

• المشاركة: ما نبيع ولا نشارك بياناتك مع طرف ثالث لأغراض تجارية. اسمك ومدينتك وصورتك تظهر بشكل عام للاعبين الثانين (بترتيب الحي وملفك العام)، أما رقم هاتفك يبقى خاص وما يظهر إلا للملعب اللي تحجز عنده.

• التخزين: بياناتك تنخزن بخدمات آمنة (Firebase و Supabase) وتنحمي حسب صلاحيات وصول محدودة.

• حقوقك: تگدر تعدّل اسمك ومدينتك وصورتك بأي وقت من هذي الشاشة، وتگدر تطلب حذف حسابك وبياناتك بالتواصل وياتنا عبر الدعم.

هذا نص مبدئي وممكن يتحدث مع تطور التطبيق.
''';

  static const String termsOfUseTitle = 'شروط الاستخدام';
  static const String termsOfUseBody = '''
باستخدامك تطبيق شوت، انت توافق على:

• التطبيق وسيط يربطك بالملاعب والمنشآت الرياضية — الحجز والدفع والالتزام بالمواعيد مسؤولية مشتركة بينك وبين الملعب.

• العربون يتأكد الحجز ويضمن إلك الوقت، والباقي (إذا موجود) يُدفع بالملعب مباشرة حسب طريقة الدفع اللي يحددها الملعب.

• الإلغاء: تگدر تلغي حجزك من "حجوزاتي"، وإذا الملعب ألغى حجزك مو بذنبك، نوفّرلك بديل وضمان حجز بدون عربون.

• عليك تستخدم بيانات صحيحة (اسمك ورقمك) وتتجنب أي إزعاج أو تصرف غير لائق تجاه اللاعبين أو أصحاب الملاعب عبر ميزة "ناقصنا لاعب" أو التقييمات.

• التطبيق ما يتحمّل مسؤولية أي نزاع مباشر بينك وبين الملعب أو لاعب ثاني خارج نطاق ميزات الحجز نفسها.

• هذي الشروط ممكن تتحدث مع تطور التطبيق، وأي تحديث مهم راح نخبرك بيه.
''';

  // نوع الحساب (أول تسجيل)
  static const String accountTypeTitle = 'وياك شنو؟';
  static const String accountTypeSubtitle =
      'اختار نوع حسابك حتى نجهّز إلك التطبيق المناسب';
  static const String accountTypePlayerTitle = 'أني لاعب';
  static const String accountTypePlayerDesc =
      'أحجز ملاعب ومنشآت رياضية، ألعب مع أهل حيّي، وأتابع إحصائياتي';
  static const String accountTypeOwnerTitle = 'أني صاحب منشأة رياضية';
  static const String accountTypeOwnerDesc =
      'أدير ملعبي أو صالتي أو مسبحي أو مركزي، وأستقبل حجوزات الزبائن';
  static const String accountTypeError =
      'ما گدرنا نحفظ اختيارك 😕 جرّب مرة ثانية';

  // هيكل صاحب المنشأة (التبويبات السفلية)
  static const String ownerShellDashboard = 'لوحة التحكم';
  static const String ownerShellBookings = 'الحجوزات';
  static const String ownerShellVenues = 'منشآتي';

  // منشآتي (صاحب المنشأة)
  static const String myVenuesTitle = 'منشآتي';
  static const String addVenueAction = 'أضف منشأة';
  static const String noVenuesTitle = 'ما عندك منشآت مسجّلة بعد';
  static const String noVenuesMessage =
      'أضف منشأتك الأولى — ملعب، صالة رياضية، مسبح، أو مركز علاج رياضي';

  // إضافة منشأة جديدة
  static const String addVenueTitle = 'أضف منشأة جديدة';
  static const String addVenueSubtitle =
      'عبّي بيانات منشأتك — تقدر تكمّل الصور وطرق الدفع بعدين من "إدارة المنشأة"';
  static const String venueTypeLabel = 'نوع المنشأة';
  static const String addVenueSubmit = 'أضف المنشأة';
  static const String venueAdded = 'انضافت منشأتك ✅ كمّل بياناتها من إدارتها';
  static const String venueAddError =
      'ما گدرنا نضيف المنشأة 😕 تأكد من الإنترنت وجرّب مرة ثانية';

  // حجوزات صاحب المنشأة (تبويب الحجوزات)
  static const String ownerBookingsTitle = 'الحجوزات';
  static const String ownerBookingsUpcoming = 'القادمة';
  static const String ownerBookingsPast = 'السابقة';
  static const String ownerBookingsEmptyUpcoming =
      'ماكو حجوزات قادمة حالياً';
  static const String ownerBookingsEmptyPast = 'ماكو حجوزات سابقة بعد';
  static const String ownerBookingsLoadError =
      'ما گدرنا نجيب الحجوزات 😕 اسحب للأسفل للتحديث';

  // إعدادات صاحب المنشأة
  static const String ownerSettingsVenuesSection = 'منشآتي';
  static const String ownerSettingsVenuesHint =
      'بيانات كل منشأة، ساعات دوامها، طرق الدفع، والصور — من هذي القائمة';

  // رقم تواصل المنشأة
  static const String venueContactPhoneLabel = 'رقم تواصل المنشأة';
  static const String venueContactPhoneHint = '07XX XXX XXXX';
  static const String venueContactPhoneDesc =
      'هذا الرقم يشوفه الزبائن ويتواصلون عليه — منفصل عن رقم حسابك الشخصي';
  static const String venueContactPhoneError =
      'رقم تواصل المنشأة لازم يبدي بـ07 ويكون 11 رقم';
  static const String venueContactPhoneRequired =
      'دخّل رقم تواصل منشأتك حتى يقدر الزبائن يتواصلون وياك';
  static const String venueContactPhoneMissingHint =
      'ما حددت رقم تواصل لهذي المنشأة بعد — الزبائن ما يگدرون يتواصلون وياك مباشرة. أضفه من "إدارة المنشأة".';
  static const String personalPhoneHint =
      'خاص — لتسجيل الدخول فقط، ما يظهر للزبائن';
  static const String contactVenueTitle = 'تواصل مع المنشأة';
  static const String contactVenueMessage =
      'هلا، شفتكم بتطبيق شوت — عندي استفسار 🙋';

  // تبديل نوع الحساب
  static const String switchAccountSection = 'نوع الحساب';
  static const String switchToOwnerLabel = 'صير صاحب منشأة';
  static const String switchToOwnerHint =
      'افتح حساب صاحب منشأة وأضف ملعبك أو مسبحك أو مركزك';
  static const String switchToPlayerLabel = 'ارجع لاعب';
  static const String switchToPlayerHint = 'ارجع لحسابك كلاعب عادي';
  static const String switchToOwnerConfirmTitle = 'تصير صاحب منشأة؟';
  static const String switchToOwnerConfirmBody =
      'راح ينفتح إلك حساب صاحب منشأة كامل — لوحة تحكم، منشآتي، وإعدادات خاصة. حسابك كلاعب (حجوزاتك وتقييماتك) يبقى محفوظ وترجعله بأي وقت.';
  static const String switchToPlayerConfirmTitle = 'ترجع لاعب؟';
  static const String switchToPlayerConfirmBody =
      'راح ترجع لحسابك كلاعب عادي. منشآتك تبقى محفوظة بالكامل وترجعلك أول ما تصير صاحب منشأة مرة ثانية.';
  static const String switchAccountConfirmAction = 'إي، أكيد';
  static const String switchAccountCancelAction = 'لا، خليه';
  static const String switchAccountError =
      'ما گدرنا نبدّل نوع حسابك 😕 جرّب مرة ثانية';

  // إعلانات صاحب المنشأة
  static const String myAdsTitle = 'إعلاناتي';
  static const String addAdAction = 'أضف إعلان';
  static const String noAdsTitle = 'ما نشرت أي إعلان بعد';
  static const String noAdsMessage =
      'انشر عرض أو خصم أو خبر بطولة — يظهر للاعبين بالرئيسية وبصفحة منشأتك';
  static const String adTitleLabel = 'عنوان الإعلان';
  static const String adTitleHint = 'مثال: خصم ٢٠٪ نهاية الأسبوع';
  static const String adTitleError = 'اكتب عنوان الإعلان';
  static const String adBodyLabel = 'نص الإعلان';
  static const String adBodyHint = 'فصّل تفاصيل العرض أو الخبر...';
  static const String adBodyError = 'اكتب نص الإعلان';
  static const String adTypeLabel = 'نوع الإعلان';
  static const String adImageLabel = 'صورة الإعلان (اختياري)';
  static const String adExpiryLabel = 'ينتهي بتاريخ';
  static const String adVenueLabel = 'المنشأة';
  static const String addAdTitle = 'إعلان جديد';
  static const String editAdTitle = 'تعديل الإعلان';
  static const String publishAdAction = 'انشر الإعلان';
  static const String saveAdAction = 'احفظ التعديلات';
  static const String adPublished = 'انتشر إعلانك ✅';
  static const String adSaved = 'انحفظ التعديل ✅';
  static const String adPublishError =
      'ما گدرنا ننشر الإعلان 😕 تأكد من الإنترنت وجرّب مرة ثانية';
  static const String adExpiredBadge = 'منتهي';
  static const String adPausedBadge = 'موقوف';
  static const String pauseAdAction = 'وقّف الإعلان';
  static const String resumeAdAction = 'فعّل الإعلان';
  static const String adPaused = 'تم إيقاف الإعلان';
  static const String adResumed = 'تم تفعيل الإعلان مرة ثانية';
  static const String deleteAction = 'حذف';
  static const String deleteAdTitle = 'حذف الإعلان';
  static const String deleteAdConfirm = 'متأكد تريد تحذف هذا الإعلان نهائياً؟';
  static const String adDeleted = 'انحذف الإعلان ✅';
  static const String adActionError = 'ما گدرنا نكمّل العملية، جرّب مرة ثانية';

  // عرض الإعلانات للاعبين
  static const String adsSectionTitle = 'العروض والإعلانات';
  static const String fieldAdsTitle = 'عروض وإعلانات المنشأة';

  // اقترح ملعب — اللاعب
  static const String suggestVenueCta = 'ما لگيت ملعبك؟ اقترحه';
  static const String suggestVenueTitle = 'اقترح ملعب';
  static const String suggestVenueIntro =
      'ملعبك المفضل مو مسجّل عدنا بعد؟ گلنا وياه ونحاول نضيفه بأقرب وقت';
  static const String suggestAreaLabel = 'المدينة/المنطقة';
  static const String suggestAreaHint = 'مثال: بغداد — المنصور';
  static const String suggestAreaError = 'اكتب المدينة أو المنطقة';
  static const String suggestMapsUrlLabel = 'رابط الموقع على الخرائط (اختياري)';
  static const String suggestMapsUrlHint = 'https://maps.google.com/...';
  static const String suggestMapsUrlError = 'رابط الخرائط لازم يبدي بـ https://';
  static const String suggestPhoneLabel = 'رقم الملعب إن تعرفه (اختياري)';
  static const String suggestNoteHint =
      'أي تفصيل يساعدنا نلگيه — علامة مميزة، قرب مكان معروف...';
  static const String suggestSubmitAction = 'ارسل الاقتراح';
  static const String suggestThankYouNew =
      'شكراً إلك! 🙏 وصلنا اقتراحك وراح نراجعه — تگدر تتابع حالته من "اقتراحاتي"';
  static const String suggestThankYouDuplicate =
      'شكراً! هذا الملعب مقترح گبل من لاعبين ثانين — زدنا صوتك إله 🙌';
  static const String suggestVenueError =
      'ما گدرنا نرسل اقتراحك 😕 تأكد من الإنترنت وجرّب مرة ثانية';

  // اقتراحاتي — اللاعب
  static const String mySuggestionsTitle = 'اقتراحاتي';
  static const String mySuggestionsItem = 'اقتراحاتي';
  static const String noSuggestionsTitle = 'ما اقترحت أي ملعب بعد';
  static const String noSuggestionsMessage =
      'ما لگيت ملعبك بالتطبيق؟ اقترحه ونحاول نضيفه لأقرب وقت';
  static String suggestionRequestersLabel(int n) =>
      n <= 1 ? 'طلبه لاعب وحد' : 'طلبه ${ArabicNum.count(n)} لاعبين';

  // لوحة إدارة الاقتراحات — للمسؤول فقط
  static const String adminSuggestionsItem = 'اقتراحات الملاعب';
  static const String adminSuggestionsTitle = 'اقتراحات الملاعب';
  static const String adminSuggestionsSubtitle =
      'مرتّبة بعدد الطلبات — الأكثر طلباً أولاً';
  static const String adminNoSuggestions = 'ماكو اقتراحات لحد هسه';
  static const String adminStatusPending = 'قيد المراجعة';
  static const String adminStatusAdded = 'انضاف';
  static const String adminStatusRejected = 'مرفوض';
  static const String adminStatusUpdated = 'انحدثت الحالة ✅';
  static const String adminStatusUpdateError =
      'ما گدرنا نحدّث الحالة 😕 جرّب مرة ثانية';
  static const String adminOpenMaps = 'افتح بالخرائط';
  static const String adminCallVenue = 'اتصل بالملعب';
  static const String adminFirstSuggestedBy = 'أول من اقترحه';
  static const String adminRequestCountUnit = 'طلب';
  static const String adminChangeStatusAction = 'غيّر الحالة';
}
