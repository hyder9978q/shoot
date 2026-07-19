#!/usr/bin/env node
/**
 * سحب الأماكن الرياضية بالعراق من Google Places API (New) → ملف JSON.
 *
 *   node tool/fetch_places.js --key=AIza... [--out=tool/places.json] [--limit=100]
 *
 * يبحث بكل مدينة × كل نوع مكان، يشيل المكرر بـ placeId، ويطلع ملف جاهز
 * للزرع بـ Firestore عبر tool/seed_firestore.js.
 *
 * الحصة اليومية بـ Google محدودة (السقف الحالي ١٠٠ طلب/يوم). فـ --limit
 * يوقف الجولة عند عدد طلبات معين، والسكربت **يكمّل من وين وقف** بالتشغيل
 * الجاي: النتائج تتراكم بـ places.json والمنجَز ينحفظ بـ places.progress.json.
 *
 * ملاحظة ترخيص: نخزن معرّف المكان ومرجع الصورة فقط — **مو الصورة نفسها**.
 * الصورة تنجلب وقت العرض بالتطبيق. مراجع الصور تتقادم، فيُعاد تشغيل
 * السكربت دورياً (شهرياً) لتحديثها.
 */

const fs = require('fs');
const path = require('path');

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || true];
  }),
);

const KEY = args.key || process.env.GOOGLE_MAPS_KEY;
const OUT = args.out || path.join(__dirname, 'places.json');
const PROGRESS = OUT.replace(/\.json$/, '.progress.json');
const LIMIT = Number(args.limit || Infinity);

if (!KEY) {
  console.error('لازم مفتاح: node tool/fetch_places.js --key=AIza...');
  process.exit(1);
}

/** قراءة ملف JSON إذا موجود، وإلا القيمة الافتراضية */
const readJson = (file, fallback) => {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
};

/** المدن المستهدفة — مركزها لتحييز البحث جغرافياً */
const CITIES = [
  { name: 'بغداد', lat: 33.3152, lng: 44.3661, radius: 25000 },
  { name: 'البصرة', lat: 30.5081, lng: 47.7835, radius: 20000 },
  { name: 'أربيل', lat: 36.1911, lng: 44.0092, radius: 20000 },
  { name: 'الموصل', lat: 36.335, lng: 43.1189, radius: 20000 },
  { name: 'النجف', lat: 32.0, lng: 44.335, radius: 15000 },
  { name: 'كربلاء', lat: 32.6167, lng: 44.0333, radius: 15000 },
  { name: 'السليمانية', lat: 35.5556, lng: 45.4351, radius: 20000 },
  { name: 'كركوك', lat: 35.4681, lng: 44.3922, radius: 15000 },
  { name: 'دهوك', lat: 36.8667, lng: 42.9889, radius: 15000 },
  { name: 'الحلة', lat: 32.4637, lng: 44.4197, radius: 15000 },
  { name: 'الناصرية', lat: 31.0439, lng: 46.2576, radius: 15000 },
  { name: 'العمارة', lat: 31.8356, lng: 47.1444, radius: 12000 },
  { name: 'الديوانية', lat: 31.9928, lng: 44.9256, radius: 12000 },
  { name: 'الكوت', lat: 32.5128, lng: 45.8181, radius: 12000 },
  { name: 'الرمادي', lat: 33.4258, lng: 43.3081, radius: 12000 },
  { name: 'تكريت', lat: 34.6, lng: 43.6833, radius: 12000 },
  { name: 'سامراء', lat: 34.1961, lng: 43.8858, radius: 12000 },
];

/** استعلامات البحث → نوع الرياضة بالتطبيق (نفس أسماء enum Sport) */
const QUERIES = [
  { q: 'ملعب خماسي', sport: 'football' },
  { q: 'ملعب كرة قدم', sport: 'football' },
  { q: 'ملعب بادل', sport: 'padel' },
  { q: 'ملعب تنس', sport: 'tennis' },
  { q: 'ملعب كرة سلة', sport: 'basketball' },
  { q: 'ملعب كرة طائرة', sport: 'volleyball' },
  { q: 'مسبح', sport: 'swimming' },
  { q: 'نادي رياضي', sport: 'gym' },
  { q: 'صالة رياضية جم', sport: 'gym' },
  { q: 'مجمع رياضي', sport: 'sportsCentre' },
];

const FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.shortFormattedAddress',
  'places.addressComponents',
  'places.location',
  'places.rating',
  'places.userRatingCount',
  'places.photos',
  'places.primaryType',
  'places.types',
  'places.nationalPhoneNumber',
  'places.regularOpeningHours',
  'places.googleMapsUri',
].join(',');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function searchText(textQuery, city) {
  const res = await fetch('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': KEY,
      'X-Goog-FieldMask': FIELD_MASK,
    },
    body: JSON.stringify({
      textQuery: `${textQuery} ${city.name}`,
      languageCode: 'ar',
      regionCode: 'IQ',
      maxResultCount: 20,
      locationBias: {
        circle: {
          center: { latitude: city.lat, longitude: city.lng },
          radius: city.radius,
        },
      },
    }),
  });

  const json = await res.json();
  if (json.error) throw new Error(`${json.error.status}: ${json.error.message}`);
  return json.places || [];
}

/** المنطقة (الحي) من مكونات العنوان — نرجع لأول جزء من العنوان إذا ما لكيناها */
function areaOf(place, cityName) {
  const comps = place.addressComponents || [];
  const pick = (type) =>
    comps.find((c) => (c.types || []).includes(type))?.longText;
  const area =
    pick('sublocality_level_1') ||
    pick('sublocality') ||
    pick('neighborhood') ||
    pick('route');
  if (area && area !== cityName) return area;

  const addr = place.shortFormattedAddress || place.formattedAddress || '';
  const first = addr.split('،')[0].trim();
  return first && first !== cityName ? first : cityName;
}

/** كتابة النتائج والتقدم — تنندى بعد كل استعلام حتى ما نضيع شي عند الانقطاع */
function save(byId, done) {
  const all = [...byId.values()].filter((p) => p.name && p.lat && p.lng);
  fs.writeFileSync(OUT, JSON.stringify(all, null, 2), 'utf8');
  fs.writeFileSync(PROGRESS, JSON.stringify([...done], null, 2), 'utf8');
  return all;
}

async function main() {
  // نكمّل من وين وقفنا: النتائج السابقة + الاستعلامات المنجزة
  /** @type {Map<string, any>} */
  const byId = new Map(readJson(OUT, []).map((p) => [p.placeId, p]));
  const done = new Set(readJson(PROGRESS, []));

  const todo = [];
  for (const city of CITIES) {
    for (const { q, sport } of QUERIES) {
      const key = `${city.name}|${q}`;
      if (!done.has(key)) todo.push({ city, q, sport, key });
    }
  }

  console.log(
    `${todo.length} استعلام باقي (${done.size} منجز) — ` +
      `${byId.size} مكان محفوظ — ميزانية هذي الجولة: ${LIMIT}`,
  );

  let calls = 0;

  for (const { city, q, sport, key } of todo) {
    if (calls >= LIMIT) {
      console.log(`\n\nوصلنا ميزانية الجولة (${LIMIT} طلب). شغّل السكربت مرة`);
      console.log('ثانية باچر (أو بعد رفع الحصة) وراح يكمّل من هنا تلقائياً.');
      break;
    }

    {
      try {
        const places = await searchText(q, city);
        calls++;
        done.add(key);
        for (const p of places) {
          const existing = byId.get(p.id);
          // نفس المكان ممكن يطلع بأكثر من استعلام — نخلي أول تصنيف
          if (existing) continue;

          byId.set(p.id, {
            placeId: p.id,
            name: p.displayName?.text?.trim() || '',
            area: areaOf(p, city.name),
            city: city.name,
            sport,
            lat: p.location?.latitude ?? 0,
            lng: p.location?.longitude ?? 0,
            rating: p.rating ?? 0,
            reviewsCount: p.userRatingCount ?? 0,
            photoName: p.photos?.[0]?.name || '',
            photoAttribution:
              p.photos?.[0]?.authorAttributions?.[0]?.displayName || '',
            phone: p.nationalPhoneNumber || '',
            mapsUri: p.googleMapsUri || '',
            googleTypes: p.types || [],
          });
        }
        process.stdout.write(
          `\r${city.name} / ${q}  →  ${byId.size} مكان (${calls} طلب)      `,
        );
      } catch (err) {
        console.error(`\n✗ ${city.name} / ${q}: ${err.message}`);
        // انتهت الحصة أو المفتاح مرفوض — نحفظ اللي جمعناه ونوقف بهدوء،
        // والتشغيل الجاي يكمّل من نفس النقطة
        if (/PERMISSION|RESOURCE_EXHAUSTED|quota/i.test(err.message)) {
          const saved = save(byId, done);
          console.error(
            `\nوقفنا بسبب الحصة/المفتاح. محفوظ ${saved.length} مكان — ` +
              'شغّل السكربت مرة ثانية بعد ما ترتفع الحصة.',
          );
          process.exit(1);
        }
      }
      await sleep(120); // تهدئة بسيطة
    }
  }

  const all = save(byId, done);
  const bySport = {};
  const withPhoto = all.filter((p) => p.photoName).length;
  for (const p of all) bySport[p.sport] = (bySport[p.sport] || 0) + 1;

  console.log(`\n\n✓ ${all.length} مكان بـ ${OUT}`);
  console.log(`  عليها صورة: ${withPhoto}`);
  console.log(`  حسب النوع:`, bySport);
  console.log(`  طلبات هذي الجولة: ${calls}`);
  console.log(`  استعلامات منجزة: ${done.size} / ${done.size + todo.length - calls}`);
}

main();
