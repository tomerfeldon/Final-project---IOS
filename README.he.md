# 🏃 RunTracker

*[English](README.md)*

אפליקציית מעקב ריצות ל-iOS. מתחילים ריצה, רואים את הזמן והמרחק מטפסים בזמן אמת
מה-GPS, שומרים כשמסיימים, ומדפדפים בכל הריצות שנרשמו.

נבנתה עם **UIKit + Storyboard**, בשפת **Swift**, ליעד **iOS 15+**, ונשענת על
**שני מסדי נתונים של Firebase** — Cloud Firestore להיסטוריית הריצות הקבועה,
ו-Realtime Database לסשן החי של הריצה המתבצעת כרגע.

> [!NOTE]
> זהו פרויקט גמר בקורס iOS. ההיקף ממוקד בכוונה: מימוש נקי ועובד של מערך תכונות
> אמיתי, ולא אפליקציה גדולה.

## תכונות

- **מעקב ריצה חי** — הזמן החולף מתעדכן כל שנייה באמצעות `Timer`, והמרחק המצטבר
  מחושב מה-GPS עם סינון רעש וקפיצות.
- **Start / Pause / Stop** — אפשר להשהות ולחדש בחופשיות; Stop שואל לפני השמירה.
- **היסטוריה קבועה** — כל ריצה שהסתיימה נשמרת ב-Firestore ומוצגת בטבלה עם תא
  מותאם (תאריך, מרחק, משך, פייס ממוצע).
- **מאזין חי (listener)** — הרשימה מתעדכנת מעצמה ברגע שריצה נשמרת, נמחקת או
  נערכת, בלי רענון ידני.
- **פרטי ריצה** — פירוט מלא לכל ריצה, מפה עם סיכות התחלה/סיום, והערה חופשית
  שנשמרת חזרה ל-Firestore.
- **המשך ריצה** — אם האפליקציה נסגרת באמצע ריצה, היא מציעה להמשיך אותה בהפעלה
  הבאה, משוחזרת מה-Realtime Database.
- **מתג יום/לילה** — מתג בלחיצה אחת בסרגל הניווט, שנשמר בין הפעלות, מעל תמיכה
  מלאה במצב התצוגה של המערכת.
- **סיבוב מסך** — כל מסך נפרש נכון במצב אנכי ואופקי בזכות Auto Layout ו-stack
  views.

## מסכים

| מסך | מה הוא עושה |
|---|---|
| **My Runs** (`RunsListController`) | היסטוריית הריצות, מהחדשה לישנה. לחיצה על ריצה פותחת פרטים, החלקה מוחקת, ו-**New Run** מתחיל ריצה. כפתור שמש/ירח מחליף יום/לילה. |
| **Active Run** (`ActiveRunController`) | זמן, מרחק ופייס חיים. Start / Pause / Stop. כותב את הסשן החי ל-Realtime Database כל שנייה. |
| **Run Details** (`RunDetailController`) | כל הנתונים של ריצה אחת, מפה של נקודות הקצה, והערה ניתנת לעריכה. |

## ערכת טכנולוגיות

- **שפה:** Swift
- **ממשק:** UIKit + Storyboard, Auto Layout (מבוסס stack views)
- **מיקום:** Core Location (`CLLocationManager`)
- **מפות:** MapKit (`MKMapView`)
- **צד שרת:** Firebase — `FirebaseCore`, `FirebaseFirestore`, `FirebaseDatabase`
- **תלויות:** Swift Package Manager
- **גרסת iOS מינימלית:** 15.0

## מבנה הפרויקט

```
RunTracker/
├── AppDelegate.swift            אתחול Firebase + הגנה ידידותית על plist חסר
├── SceneDelegate.swift          הקמת החלון
├── Model/
│   ├── Run.swift                ריצה שמורה: המרה למילון/ממנו + עיצוב לתצוגה
│   └── ActiveRunSession.swift   הסשן החי (מטען ל-Realtime DB)
├── Services/
│   ├── RunStore.swift           Firestore: האזנה / הוספה / מחיקה / עדכון הערה
│   ├── ActiveRunStore.swift     Realtime DB: כתיבת טיק / קריאה / ניקוי
│   └── RunLocationTracker.swift עטיפת CLLocationManager ← מרחק מסונן
├── Controllers/
│   ├── RunsListController.swift  טבלה + מתג יום/לילה
│   ├── ActiveRunController.swift Timer + מיקום + סשן חי
│   ├── RunDetailController.swift נתונים, מפה, עריכת הערה
│   └── SetupRequiredController.swift  מוצג רק אם ה-plist חסר
├── Views/
│   └── RunCell.swift            תא מותאם + פרוטוקול RunCellDelegate
├── Extensions/
│   └── Extensions.swift         Toast, עיצוב, ולידציה, AppTheme
└── Base.lproj/
    ├── Main.storyboard
    └── LaunchScreen.storyboard
```

שלוש מחלקות ה-`Services/` שומרות כל controller ממוקד: ה-controller אחראי על
המסך שלו, וה-service אחראי על מסד נתונים אחד או חיישן אחד. התקשורת בין התא
המותאם ל-controller שלו משתמשת בתבנית delegate/protocol (`RunCellDelegate`).

## איך מתחילים

צריך **Mac עם Xcode**. לשלבים למטה יש סדר מחייב — קראו את ההערות המודגשות.

### דרישות מקדימות

- Xcode 15 ומעלה (ראו הערת גרסת Firebase למטה עבור Xcode 16.2)
- פרויקט [Firebase](https://console.firebase.google.com) חינמי

### 1. קונסולת Firebase

> [!IMPORTANT]
> צרו את **שני** מסדי הנתונים **לפני** רישום אפליקציית ה-iOS. המפתח
> `DATABASE_URL` נכתב לתוך `GoogleService-Info.plist` רק אם ה-Realtime Database
> כבר קיים — אחרת האפליקציה נכשלת בזמן ריצה בצורה שנראית כמו באג בקוד.

1. **Add project** → קראו לו `RunTracker` (Google Analytics לא נחוץ).
2. **Build → Firestore Database → Create database** → **test mode** → בחרו אזור.
3. **Build → Realtime Database → Create database** → **test mode**.
4. **Add app → iOS**, bundle ID `com.tomer.RunTracker`, הורידו
   `GoogleService-Info.plist`.

> [!NOTE]
> מצב test משאיר את שני מסדי הנתונים פתוחים, והכללים שלו פגים אחרי 30 יום. זה
> בסדר לפרויקט לימודי — אם קריאות מתחילות להיכשל אחרי שבועות, זו הסיבה.

### 2. פרויקט Xcode

1. **File → New → Project → iOS → App.** Product Name `RunTracker`, Interface
   **Storyboard**, Language **Swift**, bundle ID `com.tomer.RunTracker`. הגדירו
   deployment target ל-**iOS 15.0**.
2. **מחקו קודם את קבצי התבנית** — הריפו הזה מספק גרסאות משלו. בחרו ו-**Move to
   Trash**: `AppDelegate.swift`, `SceneDelegate.swift`, `ViewController.swift`,
   `Main.storyboard`, `LaunchScreen.storyboard`, `Assets.xcassets`. השארתם גורמת
   לשגיאות `invalid redeclaration`.
3. הוסיפו את קוד המקור מהריפו. גררו את `Model`, `Services`, `Controllers`,
   `Views`, `Extensions`, `Assets.xcassets`, וגם `AppDelegate.swift` /
   `SceneDelegate.swift` לתוך קבוצת `RunTracker` הריקה (*Copy items if needed*,
   *Create groups*, הטרגט מסומן).

   > [!WARNING]
   > הוסיפו את שני ה-storyboards כ**קבצים בודדים**, לא על ידי גרירת התיקייה
   > `Base.lproj` כולה. לפרויקט חדש כבר יש `Base.lproj`, וגרירת עוד אחת יוצרת
   > `Base 2.lproj` תועה שהאפליקציה לא מוצאת — תקבלו קריסת runtime
   > `Could not find a storyboard named 'Main'`. גררו את `Main.storyboard`
   > ו-`LaunchScreen.storyboard` בנפרד.

4. גררו פנימה את `GoogleService-Info.plist` האמיתי שלכם (הטרגט מסומן). **אל
   תשנו** את השם של `GoogleService-Info.SAMPLE.plist` — הוא רק קובץ ייחוס.
5. **File → Add Package Dependencies** → `https://github.com/firebase/firebase-ios-sdk`.
   הוסיפו בדיוק את `FirebaseCore`, `FirebaseFirestore`, `FirebaseDatabase`.

   > [!IMPORTANT]
   > **ב-Xcode 16.2 ומטה,** Firebase 12.15+ דורש ערכת כלים חדשה יותר וייכשל
   > בפתרון. בדיאלוג Add Package הגדירו את ה-Dependency Rule ל-**Up to Next
   > Major Version** החל מ-**11.0.0** כדי למשוך גרסת Firebase 11.x. ה-API זהה.
   > בבחירת המוצרים, הגדירו כל מוצר חוץ משלושת אלה ל-**None** (הרשימה נגללת —
   > השלושה נמצאים מתחת לרשומות `FirebaseAnalytics*`).

6. **Target → Info** → הוסיפו **Privacy - Location When In Use Usage
   Description** (`NSLocationWhenInUseUsageDescription`) עם ערך כמו
   `RunTracker uses your location to measure the distance of your runs.` בלעדיו,
   iOS מסרב בשקט להציג את בקשת ההרשאה.
7. **Target → General → Device Orientation:** הפעילו Portrait, Landscape Left
   ו-Landscape Right.
8. **Build and run.**

> [!TIP]
> ה-GPS של הסימולטר סינתטי. כדי שהמרחק יזוז, בחרו **Features → Location → City
> Run** בסימולטר, ואז לחצו Start.

## איך זה עובד: שני מסדי נתונים, בכוונה

הרעיון של הפרויקט הוא להשתמש בכל מסד נתונים למה שהוא טוב בו.

**Cloud Firestore** — היסטוריית ריצות קבועה וניתנת לחיפוש:

```
runs/
  <auto-id>/
    date, distanceMeters, durationSeconds, averagePaceSecPerKm,
    startLat, startLng, endLat, endLng, note
```

נקרא עם `addSnapshotListener`, כך שהרשימה מצטיירת מחדש ברגע שמשהו משתנה — בלי
רענון ידני, מקור אמת יחיד.

**Realtime Database** — הסשן החי בלבד, בזמן שריצה מתבצעת:

```
activeRun/
  isActive, elapsedSeconds, distanceMeters, startTimestamp
```

נדרס כל שנייה במהלך ריצה ונמחק עם `removeValue()` כשהיא מסתיימת. בהפעלה, אם
`isActive` הוא `true`, האפליקציה מציעה להמשיך.

> ערך קטן, חם וזמני שנכתב פעמים רבות בשנייה הוא בדיוק מה ש-Realtime Database בנוי
> בשבילו; רשומות עמידות ששומרים ומחפשים הן מה ש-Firestore בנוי בשבילו. לכן שניהם
> כאן.

שני פרטי מימוש ששווה להדגיש:

- **השעון נגזר מתאריכים, לא נספר.** `Timer` לא מבטיח דיוק בזמן אמת, ולכן הזמן
  החולף מחושב כ-`Date().timeIntervalSince(start)` בכל טיק. הטיימר רק מפעיל רענון;
  הוא לעולם לא מקור האמת.
- **ה-GPS מסונן.** נקודות לא-מדויקות, ישנות, או כאלה שמרמזות על מהירות לא-סבירה
  (תקלת אות או קפיצה בסימולטר) נדחות, כך שעמידה במקום לא ממציאה מרחק וקפיצה לא
  מוסיפה קילומטרים.

## דרישות הקורס

| דרישה | היכן |
|---|---|
| Table View + תא מותאם | `RunsListController`, `Views/RunCell.swift` |
| Firestore | `Services/RunStore.swift` |
| Realtime Database | `Services/ActiveRunStore.swift` |
| Location | `Services/RunLocationTracker.swift` |
| Timers | `ActiveRunController` |
| Dark Mode | צבעים סמנטיים + ערכת צבע `AccentGreen` + מתג ידני (`AppTheme`) |
| סיבוב מסך | Auto Layout + stack views; נתוני הריצה מתארגנים מחדש במצב אופקי |
| תבנית delegate | `RunCellDelegate` בין התא ל-controller שלו |

## מגבלות ידועות

- **אין מיקום ברקע.** האפליקציה מבקשת "when in use" בלבד, אז המעקב נעצר אם עוזבים
  אותה באמצע ריצה. מעקב רציף היה דורש את יכולת Background Modes ובקשת הרשאת
  "always", מעבר להיקף הפרויקט.
- **אין אימות.** כל הריצות חולקות אוסף אחד. Firebase Auth והפרדה לפי משתמש היו
  הצעד הטבעי הבא.
- **ה-GPS של הסימולטר סינתטי.** דיוק אמיתי דורש מכשיר פיזי.
