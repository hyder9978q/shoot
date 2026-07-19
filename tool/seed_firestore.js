#!/usr/bin/env node
/**
 * زرع الأماكن المسحوبة (tool/places.json) بمجموعة `fields` بـ Firestore.
 *
 *   node tool/seed_firestore.js --sa=serviceAccount.json [--in=tool/places.json] [--dry]
 *
 * مفتاح حساب الخدمة: Firebase Console → Project Settings → Service Accounts
 * → Generate new private key. (لا تحطه بالمستودع — مضاف بـ .gitignore)
 *
 * معرّف المستند = placeId، فإعادة التشغيل تحدّث نفس المكان بدل ما تكرره.
 * merge:true حتى ما نمسح البيانات اللي حددها صاحب الملعب (السعر، الوصف،
 * المرافق، ساعات الدوام) لما نجدد الصور والتقييمات من Google.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || true];
  }),
);

const SA = args.sa;
const IN = args.in || path.join(__dirname, 'places.json');
const DRY = Boolean(args.dry);

if (!SA && !DRY) {
  console.error('لازم حساب خدمة: node tool/seed_firestore.js --sa=serviceAccount.json');
  process.exit(1);
}

const places = JSON.parse(fs.readFileSync(IN, 'utf8'));

/** الحقول اللي نجدّدها من Google بكل تشغيل — الباقي يبقى للمالك */
const refreshable = (p) => ({
  name: p.name,
  area: p.area,
  city: p.city,
  sport: p.sport,
  lat: p.lat,
  lng: p.lng,
  rating: p.rating,
  reviewsCount: p.reviewsCount,
  photoName: p.photoName,
  photoAttribution: p.photoAttribution,
  phone: p.phone,
  placeId: p.placeId,
  mapsUri: p.mapsUri,
  source: 'google',
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

/** تنحط مرة وحدة عند الإنشاء بس — لأن المالك ممكن يعدّلها بعدين */
const onCreate = {
  pricePerHour: 0, // ٠ = "اتصل للسعر"، لحد ما صاحب المكان يسجّل ويحدد
  ownerId: '',
  imageUrl: '',
  description: '',
  amenities: [],
  openHour: 16,
  closeHour: 24,
  isActive: true,
};

async function main() {
  const bySport = {};
  for (const p of places) bySport[p.sport] = (bySport[p.sport] || 0) + 1;
  const withPhoto = places.filter((p) => p.photoName).length;

  console.log(`${places.length} مكان بالملف — عليها صورة: ${withPhoto}`);
  console.log('حسب النوع:', bySport);

  if (DRY) {
    console.log('\n(تجربة فقط — ما تكتب شي بـ Firestore)');
    console.log('عيّنة:', JSON.stringify(places.slice(0, 2), null, 2));
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(SA))),
  });
  const db = admin.firestore();

  // نعرف شنو موجود مسبقاً حتى ما ندهس السعر اللي حدده المالك
  const existing = new Set();
  const snap = await db.collection('fields').get();
  snap.forEach((d) => existing.add(d.id));

  let created = 0;
  let updated = 0;

  // دفعات 400 (حد الدفعة بـ Firestore هو 500 عملية)
  for (let i = 0; i < places.length; i += 400) {
    const batch = db.batch();
    for (const p of places.slice(i, i + 400)) {
      const ref = db.collection('fields').doc(p.placeId);
      const isNew = !existing.has(p.placeId);
      batch.set(
        ref,
        isNew ? { ...onCreate, ...refreshable(p) } : refreshable(p),
        { merge: true },
      );
      isNew ? created++ : updated++;
    }
    await batch.commit();
    process.stdout.write(`\rكُتب ${Math.min(i + 400, places.length)}/${places.length}   `);
  }

  console.log(`\n\n✓ جديد: ${created} — محدّث: ${updated}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
