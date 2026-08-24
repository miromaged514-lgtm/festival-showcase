# 📖 شرح مشروع "معرض المهرجان" — من الألف للياء

> ملف مرجعي شامل ومنظم لمناقشة اللجنة. اقرأيه بالترتيب.

---

## 1. الفكرة والمتطلبات

**"معرض المهرجان"** موقع ويب تفاعلي بيسمح لمستخدمين بدورين مختلفين إنهم يشاركوا أعمال (صور / PDF / فيديو) ويتفاعلوا معاها.

### الأدوار
| الدور | صلاحياته |
|-------|----------|
| **مخدوم (Served)** | يرفع أعمال (بتدخل في حالة `pending`)، يتفاعل، يعلّق، يمسح **أعماله وتعليقاته** بس |
| **خادم (Servant)** | نفس صلاحيات المخدوم + منشوراته `approved` تلقائياً + بيوافق على منشورات المخدومين + بيقدر يمسح **أي منشور أو تعليق** + بيقيّم الأعمال (1–5) |

### مميزات إضافية
- دعم لغتين: **عربي (RTL)** و **إنجليزي (LTR)** مع تبديل فوري.
- ثيم **دارك / لايت**.
- بحث بالاسم أو عنوان العمل.
- تعليقات وريأكشنز (👍 ❤️ ✨ 🙏).
- صفحة إعدادات لتغيير الاسم / كلمة السر / اللغة / الثيم.

---

## 2. الـ Stack التقني

### Frontend
- **React 19** + **TypeScript** (strict mode)
- **TanStack Start v1** — SSR framework
- **TanStack Router** — file-based routing type-safe
- **TanStack Query** — إدارة الـ server state والـ cache
- **Tailwind CSS v4** + **shadcn/ui** — تصميم
- **Vite 7** — build tool
- **lucide-react** — أيقونات
- **sonner** — إشعارات (toast)

### Backend
- **Supabase** — يوفر:
  - **Postgres** كقاعدة بيانات
  - **Auth** لتسجيل الدخول (Email + Password)
  - **Storage** لتخزين الملفات (bucket خاص باسم `works`)
  - **RLS (Row Level Security)** لحماية البيانات على مستوى الصف

### Deployment
- **Cloudflare Worker runtime** عن طريق nitro (يبني SSR entry تلقائياً).
- ينشر على **Lovable Cloud** أو **Vercel**.

---

## 3. هيكل المجلدات

```
project/
├── src/
│   ├── routes/                       # الصفحات (file-based routing)
│   │   ├── __root.tsx                # الـ shell + كل الـ providers
│   │   ├── index.tsx                 # / → redirect
│   │   ├── auth.tsx                  # /auth → تسجيل / دخول
│   │   └── _authenticated/           # صفحات محمية (لازم user مسجّل)
│   │       ├── route.tsx             # الـ auth gate + الـ Header
│   │       ├── gallery.tsx           # /gallery → المعرض
│   │       ├── upload.tsx            # /upload → رفع عمل
│   │       ├── my-works.tsx          # /my-works → أعمالي
│   │       ├── pending.tsx           # /pending → موافقات (خادم فقط)
│   │       ├── settings.tsx          # /settings → إعدادات
│   │       └── work.$id.tsx          # /work/:id → تفاصيل العمل
│   │
│   ├── lib/                          # منطق مشترك
│   │   ├── auth.tsx                  # AuthProvider + useAuth
│   │   ├── i18n.tsx                  # نظام الترجمة العربي/الإنجليزي
│   │   ├── theme.tsx                 # ThemeProvider (dark/light)
│   │   ├── media.ts                  # detectMediaType + MAX_SIZE
│   │   └── utils.ts                  # cn() → دمج classes
│   │
│   ├── components/
│   │   ├── SignedMedia.tsx           # عرض ملفات من bucket خاص عن طريق signed URL
│   │   └── ui/                       # مكونات shadcn (Button, Card, Input, ...)
│   │
│   ├── integrations/supabase/        # ملفات auto-generated ⚠️ ماتلمسيهاش
│   │   ├── client.ts                 # supabase client في المتصفح
│   │   ├── client.server.ts          # supabase admin (server فقط)
│   │   ├── auth-middleware.ts        # middleware للـ server functions
│   │   ├── auth-attacher.ts          # بيرفق الـ bearer token
│   │   └── types.ts                  # الأنواع من الـ schema
│   │
│   ├── assets/festival-logo.jpg      # شعار المهرجان (خلفية)
│   ├── styles.css                    # Tailwind + design tokens
│   ├── router.tsx                    # إنشاء الـ TanStack Router
│   ├── start.ts                      # server entry + middlewares
│   └── routeTree.gen.ts              # auto-generated ⚠️
│
├── supabase/config.toml              # إعدادات Supabase (auto-managed)
└── vite.config.ts                    # إعدادات Vite
```

---

## 4. شرح تفصيلي للملفات المهمة

### 4.1 `src/routes/__root.tsx` — الـ Shell والـ Providers

ده الـ layout الجذر اللي كل الصفحات بتتغلف بيه.

```tsx
export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [ /* SEO metadata: title, description, og tags */ ],
    links: [ { rel: "stylesheet", href: appCss } ],
  }),
  shellComponent: RootShell,       // يرسم <html><body>
  component: RootComponent,         // المحتوى داخل الـ body
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});
```

**الأجزاء الأساسية:**

1. **`RootShell`** — بيرسم الـ HTML كامل (`<html dir="rtl">`) + بيحقن `<HeadContent />` (للـ meta tags) و `<Scripts />` (بندل JS).

2. **`RootComponent`** — بيغلف الأبلكيشن بالـ providers بالترتيب ده:
   ```tsx
   <QueryClientProvider>        // TanStack Query cache
     <I18nProvider>              // اللغة والاتجاه
       <ThemeProvider>           // دارك / لايت
         <AuthProvider>          // session + role
           <GlobalBackdrop />    // خلفية الشعار المشوّشة
           <Outlet />            // الصفحة الحالية
           <Toaster />           // toasts
   ```

3. **`GlobalBackdrop`** — صورة الشعار في وسط الشاشة بـ `blur-sm` و `opacity-40` (لايت) / `opacity-20` (دارك)، `fixed inset-0 z-0` عشان تفضل خلفية لكل الصفحات.

4. **`NotFoundComponent`** — صفحة 404 بالعربي.

5. **`ErrorComponent`** — بتبان لو حصل throw في أي loader / component. فيه زرار "حاول تاني" بيعمل `router.invalidate() + reset()`.

---

### 4.2 `src/router.tsx` — إنشاء الـ Router

```tsx
export const getRouter = () => {
  const queryClient = new QueryClient();
  const router = createRouter({
    routeTree,                    // الشجرة الـ auto-generated
    context: { queryClient },     // متاح لكل loader و component
    scrollRestoration: true,
    defaultPreloadStaleTime: 0,   // preload الـ routes عند hover
  });
  return router;
};
```

`getRouter` بتترجع router جديد لكل request (server-side) عشان الـ cache ما يتشاركش بين المستخدمين.

---

### 4.3 `src/start.ts` — Server Entry + Middlewares

```tsx
const errorMiddleware = createMiddleware().server(async ({ next }) => {
  try { return await next(); }
  catch (error) {
    if (error?.statusCode) throw error;  // errors مقصودة (401, redirect)
    return new Response(renderErrorPage(), { status: 500 });
  }
});

export const startInstance = createStart(() => ({
  functionMiddleware: [attachSupabaseAuth],  // بيرفق الـ Authorization header
  requestMiddleware: [errorMiddleware],
}));
```

- `attachSupabaseAuth` بيقرأ الـ session ويرفق `Bearer <token>` مع كل server function call.
- `errorMiddleware` بيلف كل server request في try/catch عشان ما نطلعش stack traces للمستخدم.

---

### 4.4 `src/routes/index.tsx` — الـ Redirect الأولي

```tsx
export const Route = createFileRoute("/")({
  ssr: false,                                    // ما نـ SSR الـ redirect (session في localStorage)
  beforeLoad: async () => {
    const { data } = await supabase.auth.getUser();
    if (!data.user) throw redirect({ to: "/auth" });
    throw redirect({ to: "/gallery" });
  },
  component: () => null,
});
```

- لو مفيش user → روح لـ `/auth`.
- لو فيه user → روح لـ `/gallery`.
- `ssr: false` لأن الـ session بتتخزن في `localStorage` واللي server ما يقدرش يقرأها.

---

### 4.5 `src/routes/auth.tsx` — صفحة تسجيل / دخول

**الحالة المحلية:**
```tsx
const [mode, setMode] = useState<"login" | "signup">("login");
const [email, setEmail] = useState("");
const [password, setPassword] = useState("");
const [displayName, setDisplayName] = useState("");
const [role, setRole] = useState<"servant" | "served">("served");
```

**عند التسجيل (signup):**
```tsx
await supabase.auth.signUp({
  email, password,
  options: {
    emailRedirectTo: window.location.origin,
    data: { display_name: displayName, role },   // metadata يقراها الـ trigger
  },
});
```

الـ `data` بتُخزّن في `auth.users.raw_user_meta_data`، وبعدين الـ trigger `handle_new_user` بيقراها ويعمل insert في `profiles` و `user_roles`.

**عند الدخول (login):**
```tsx
await supabase.auth.signInWithPassword({ email, password });
```

بعد النجاح: `router.invalidate() + navigate({ to: "/" })` → الـ `index.tsx` بيعمل redirect لـ `/gallery`.

---

### 4.6 `src/routes/_authenticated/route.tsx` — الـ Auth Gate

**ده أهم ملف في نظام الحماية.** لأنه pathless layout (بيبدأ بـ `_`)، كل الملفات جواه بتتحمي أوتوماتيكياً.

```tsx
export const Route = createFileRoute("/_authenticated")({
  ssr: false,                                    // مهم!
  beforeLoad: async () => {
    const { data } = await supabase.auth.getUser();
    if (!data.user) throw redirect({ to: "/auth" });
    return { user: data.user };
  },
  component: AuthedLayout,
});
```

- `beforeLoad` بيتنفذ **قبل** ما الصفحة الابن تتحمل. لو مفيش user، بيعمل throw redirect لـ `/auth`.
- `ssr: false` عشان `localStorage` مش موجود في الـ server → لو نفذنا الـ gate على السيرفر هيحصل redirect loop.

**الـ Layout (`AuthedLayout`)** فيه:
- **Header ثابت** (`sticky top-0`) فيه:
  - شعار + اسم الموقع
  - Nav links: Gallery / Upload / My Works / (Pending لو خادم)
  - أزرار: Toggle theme, Toggle language, Settings, Logout
- **`<main>`** فيه `<Outlet />` للصفحة الابن.

**Logout:**
```tsx
async function logout() {
  await queryClient.cancelQueries();  // امنع أي refetch جاي
  queryClient.clear();                 // امسح الكاش (مهم للـ RLS)
  await supabase.auth.signOut();
  router.invalidate();
  navigate({ to: "/auth", replace: true });
}
```

---

### 4.7 `src/routes/_authenticated/gallery.tsx` — المعرض

**الفكرة:** يعرض كل الأعمال بحالة `approved` فقط.

**Data fetching:**
```tsx
useQuery({
  queryKey: ["gallery", "approved"],
  queryFn: async () => {
    // 1. جيب الأعمال المعتمدة
    const { data } = await supabase
      .from("works")
      .select("id,title,description,media_url,media_type,rating,created_at,owner_id")
      .eq("status", "approved")
      .order("created_at", { ascending: false });

    // 2. جيب أسماء الملاك في query منفصلة (بدل foreign key embedding)
    const ownerIds = [...new Set(data.map(r => r.owner_id))];
    const { data: profs } = await supabase
      .from("profiles").select("id, display_name").in("id", ownerIds);

    // 3. ادمج
    const map = new Map(profs.map(p => [p.id, p.display_name]));
    data.forEach(r => { r.profiles = { display_name: map.get(r.owner_id) }; });
    return data;
  },
});
```

⚠️ **ليه query منفصلة بدل من `.select("*, profiles(display_name)")`؟** لأن الـ foreign key embedding محتاج علاقة FK صريحة والـ RLS بتعقد الموضوع، فبنجيبها يدوي.

**البحث:**
```tsx
const filtered = useMemo(() => {
  const term = q.trim().toLowerCase();
  if (!term) return data;
  return data.filter(w =>
    w.title.toLowerCase().includes(term) ||
    w.description.toLowerCase().includes(term) ||
    w.profiles?.display_name?.toLowerCase().includes(term)
  );
}, [data, q]);
```

بحث محلي (client-side) على العنوان، الوصف، أو اسم صاحب العمل.

**العرض:** grid بـ 3 أعمدة (`grid gap-4 sm:grid-cols-2 lg:grid-cols-3`) وكل card فيه:
- Thumbnail عبر `<SignedMedia variant="thumb" />`.
- Badge لنوع الميديا (image / pdf / video).
- Badge للتقييم لو > 0.
- العنوان، اسم الرافع، الوصف.

---

### 4.8 `src/routes/_authenticated/upload.tsx` — رفع عمل

**العملية بالخطوات:**

```tsx
async function submit(e) {
  // 1. تحقق من الحجم والنوع
  if (file.size > MAX_SIZE) return toast.error("الملف كبير جدًا");
  const mediaType = detectMediaType(file);   // image / pdf / video
  if (!mediaType) return toast.error("نوع غير مدعوم");

  // 2. ارفع للـ storage تحت مجلد المستخدم
  const path = `${user.id}/${crypto.randomUUID()}.${ext}`;
  await supabase.storage.from("works").upload(path, file, {
    contentType: file.type,
    upsert: false,
  });

  // 3. أدخل صف في جدول works
  await supabase.from("works").insert({
    owner_id: user.id,
    title, description,
    media_url: path,
    media_type: mediaType,
    status: role === "servant" ? "approved" : "pending",   // ⚠️ الفرق بين الدورين
  });

  navigate({ to: "/my-works" });
}
```

**النقطة المهمة (سطر 51):**
- الخادم منشوره `approved` مباشرة → يبان في المعرض فوراً.
- المخدوم منشوره `pending` → لازم خادم يوافق عليه.

---

### 4.9 `src/routes/_authenticated/pending.tsx` — الموافقات (خادم فقط)

- بيجيب الأعمال بحالة `pending`.
- بيعرض لكل عمل: زر **موافقة** (يغيّر `status` لـ `approved`) وزر **رفض** (يغيّر لـ `rejected` أو يمسحه).
- محمي على مستوى الـ RLS (السياسة `Servants read pending`) بحيث لو مخدوم فتح `/pending` مش هيرجع بيانات.
- في الـ header، الـ nav link لـ `/pending` بيبان فقط لو `role === "servant"`.

---

### 4.10 `src/routes/_authenticated/work.$id.tsx` — تفاصيل العمل

ده أكبر ملف لأنه بيدير: عرض العمل، ريأكشنز، تعليقات، حذف، تقييم.

**Queries متوازية:**
```tsx
const workQ = useQuery({ queryKey: ["work", id], queryFn: ... });      // العمل + صاحبه
const reactionsQ = useQuery({ queryKey: ["reactions", id], ... });      // كل الريأكشنز
const commentsQ = useQuery({ queryKey: ["comments", id], ... });        // التعليقات + أسماء أصحابها
```

**Mutations:**
1. **`react`** — لو دست على نفس الريأكشن اللي حاطها → `delete`. لو ريأكشن مختلفة → `update`. لو أول مرة → `insert`.
2. **`postComment`** — insert في `comments`.
3. **`deleteComment`** — protected بالـ RLS (المالك أو الخادم).
4. **`deleteWork`** — بيمسح الملف من الـ storage الأول، بعدين الصف.
5. **`updateRating`** — الخادم فقط (يظهر الزر لما `role === "servant"`).

**صلاحية الحذف (سطر 175):**
```tsx
const canDeleteWork = user?.id === w.owner_id || role === "servant";
```

**زرار الرجوع (سطر 180-191):**
```tsx
<Button onClick={() => {
  if (window.history.length > 1) router.history.back();
  else navigate({ to: "/gallery" });
}}>
```

الأيقونة `ArrowRight` في RTL و `ArrowLeft` في LTR.

**عرض الميديا:**
```tsx
<SignedMedia path={w.media_url} mediaType={w.media_type} variant="full" controls />
```

`variant="full"` بيعرض المحتوى كامل: صورة، مشغّل فيديو، أو زرار "افتح PDF".

---

### 4.11 `src/routes/_authenticated/settings.tsx` — الإعدادات

بيعرض:
- **بطاقة نوع الحساب** — بتبين "خادم" أو "مخدوم".
- **تعديل الاسم** — `update` على `profiles.display_name`.
- **تغيير كلمة السر** — `supabase.auth.updateUser({ password: newPassword })`.
- **تبديل الثيم** — يستدعي `theme.toggle()`.
- **تبديل اللغة** — يستدعي `setLang()`.

---

### 4.12 `src/lib/auth.tsx` — نظام المصادقة

```tsx
export function AuthProvider({ children }) {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState<AppRole | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchRole = async (uid) => {
    const { data } = await supabase.from("user_roles")
      .select("role").eq("user_id", uid).maybeSingle();
    setRole(data?.role ?? null);
  };

  useEffect(() => {
    // 1. اشترك في تغيّرات الـ auth (SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED)
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
      setUser(s?.user ?? null);
      if (s?.user) setTimeout(() => fetchRole(s.user.id), 0);  // avoid deadlock
      else setRole(null);
    });

    // 2. اقرأ الـ session الحالية عند التحميل
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setUser(data.session?.user ?? null);
      if (data.session?.user) fetchRole(data.session.user.id).finally(() => setLoading(false));
      else setLoading(false);
    });

    return () => sub.subscription.unsubscribe();
  }, []);
  ...
}
```

⚠️ **ليه `setTimeout(..., 0)` قبل `fetchRole`؟** عشان لو نداهيت supabase جوه callback الـ `onAuthStateChange` بشكل sync ممكن يحصل deadlock (توثيق supabase موصّي بده).

---

### 4.13 `src/lib/i18n.tsx` — نظام الترجمة

- بيخزّن اللغة في `localStorage` تحت مفتاح `lang`.
- بيوفّر function `t(key)` بترجع النص المترجم.
- بيوفّر `dir` = `"rtl"` أو `"ltr"`.
- بيحدّث `document.documentElement.dir` تلقائياً في `useEffect`.
- **يجنّب Hydration Mismatch:** الحالة الأولية ثابتة (`"ar"`)، وبعد الـ mount بيحدّث من localStorage جوه `useEffect`.

---

### 4.14 `src/lib/theme.tsx` — الثيم

نفس مبدأ i18n:
- بيخزّن `"dark"` أو `"light"` في localStorage.
- بيضيف/يشيل class `dark` من `<html>`.
- بيوفّر `toggle()` لـ header.

---

### 4.15 `src/lib/media.ts` — كشف نوع الملف

```tsx
export const MAX_SIZE = 50 * 1024 * 1024;   // 50 MB

export function detectMediaType(file: File): "image" | "pdf" | "video" | null {
  if (file.type.startsWith("image/")) return "image";
  if (file.type === "application/pdf") return "pdf";
  if (file.type.startsWith("video/")) return "video";
  return null;
}
```

---

### 4.16 `src/components/SignedMedia.tsx` — عرض ملفات محمية

الـ bucket `works` **خاص (private)** فماينفعش نستخدم URL مباشر. لازم نطلب من supabase **signed URL** (رابط مؤقت موقّع).

```tsx
export function useSignedUrl(path: string) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    supabase.storage.from("works").createSignedUrl(path, 3600)
      .then(({ data }) => setUrl(data?.signedUrl ?? null));
  }, [path]);
  return url;
}
```

مدة الرابط ساعة (`3600`s). المكون بيعرض:
- **image** → `<img src={url} />`
- **video** → `<video src={url} controls />`
- **pdf (variant="full")** → زر "افتح الملف" بيفتح `url` في تاب جديد (تجنبنا `iframe` لأن Chrome بيحظرها من نطاق مختلف).
- **pdf (variant="thumb")** → أيقونة PDF.

---

### 4.17 `src/integrations/supabase/client.ts` — العميل المتصفحي

**Auto-generated ⚠️ ماتلمسيهاش.**

- بينشئ supabase client بمفاتيح `VITE_SUPABASE_URL` و `VITE_SUPABASE_PUBLISHABLE_KEY`.
- الجديد: بيتعامل مع مفاتيح `sb_publishable_*` (opaque) بدل JWT keys — بيشيل الـ `Authorization: Bearer <key>` ويحطّها بس في header `apikey`.
- بيحفظ الـ session في `localStorage`.
- بيستخدم Proxy عشان lazy initialization.

---

## 5. قاعدة البيانات (Postgres Schema)

### 5.1 الـ Enums

```sql
CREATE TYPE app_role AS ENUM ('servant', 'served');
CREATE TYPE work_type AS ENUM ('image', 'pdf', 'video');
CREATE TYPE work_status AS ENUM ('pending', 'approved', 'rejected');
```

### 5.2 الجداول

#### `profiles`
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### `user_roles` (منفصل عن profiles — أمان!)
```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);
```
⚠️ **مهم:** الدور مش في `profiles` عشان لو حصل عندنا policy غلط ما ينفعش المستخدم يعمل update لدوره.

#### `works`
```sql
CREATE TABLE works (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  media_url TEXT NOT NULL,         -- المسار داخل bucket
  media_type work_type NOT NULL,
  status work_status DEFAULT 'pending',
  rating INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### `reactions`
```sql
CREATE TABLE reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id UUID REFERENCES works(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,               -- like / love / wow / pray
  UNIQUE (work_id, user_id)         -- ريأكشن واحدة لكل user لكل عمل
);
```

#### `comments`
```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id UUID REFERENCES works(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 5.3 الدوال (Functions)

#### `private.has_role` — دالة أمنية (SECURITY DEFINER)
```sql
CREATE OR REPLACE FUNCTION private.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER    -- تشتغل بصلاحيات صاحب الدالة، مش المستخدم
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;
```

⚠️ **ليه `SECURITY DEFINER`؟** عشان في policies بتناديها، ولو كانت `SECURITY INVOKER` هيحصل recursive RLS check → infinite loop.

⚠️ **ليه في `private` schema مش `public`؟** عشان مايتعرضش من API الـ Data الخاصة بـ Supabase (فقط policies داخلية تقدر تناديها).

#### `handle_new_user` — Trigger عند تسجيل مستخدم جديد
```sql
CREATE FUNCTION handle_new_user() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _role app_role;
BEGIN
  INSERT INTO profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name',
                            split_part(NEW.email, '@', 1)));

  _role := COALESCE((NEW.raw_user_meta_data->>'role')::app_role, 'served');
  INSERT INTO user_roles (user_id, role) VALUES (NEW.id, _role)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END; $$;

-- ربط بجدول auth.users
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

بمجرد ما مستخدم جديد يتسجل، الـ trigger بيقرأ الـ metadata (`display_name` و `role`) وينشئ الصفوف المطلوبة.

### 5.4 سياسات الـ RLS (أهم جزء في الأمان)

#### `profiles`
```sql
CREATE POLICY "Authenticated read profiles" ON profiles
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

#### `user_roles`
```sql
-- بس مستخدم مسجّل يقدر يقرأ دور نفسه
CREATE POLICY "Read own role" ON user_roles
  FOR SELECT USING (auth.uid() = user_id);
```

#### `works`
```sql
-- كل مستخدم يقدر يشوف الأعمال المعتمدة
CREATE POLICY "Read approved works" ON works
  FOR SELECT TO authenticated USING (status = 'approved');

-- المالك يقدر يشوف أعماله (حتى لو pending)
CREATE POLICY "Owner reads own works" ON works
  FOR SELECT USING (auth.uid() = owner_id);

-- الخادم يقدر يشوف الـ pending للموافقة
CREATE POLICY "Servants read pending" ON works
  FOR SELECT USING (private.has_role(auth.uid(), 'servant'));

-- إدخال: بس المالك على نفسه
CREATE POLICY "Insert own work" ON works
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- تحديث: المالك على عمله، أو الخادم للتقييم/الموافقة
CREATE POLICY "Owner updates own work" ON works
  FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Servants update any" ON works
  FOR UPDATE USING (private.has_role(auth.uid(), 'servant'));

-- حذف
CREATE POLICY "Owner deletes own" ON works
  FOR DELETE USING (auth.uid() = owner_id);
CREATE POLICY "Servants delete any" ON works
  FOR DELETE USING (private.has_role(auth.uid(), 'servant'));
```

#### `reactions` و `comments`
- Read: أي مستخدم مسجّل.
- Insert: `auth.uid() = user_id` (مايقدرش يحط ريأكشن باسم غيره).
- Delete على `comments`: المالك أو الخادم.

#### Storage bucket `works`
- Bucket `Public = false`.
- Read policy: بس المستخدم المسجّل يقدر يعمل `select` على object في المسار بتاعه أو أي مسار (نستخدم signed URL على أي حال).
- Insert: بس في مجلد `${auth.uid()}/*`.

---

## 6. تدفق العمل (Flows)

### 6.1 تدفق التسجيل والدخول

```text
┌──────────────┐     ┌────────────────┐     ┌──────────────────┐
│  المستخدم    │────▶│   /auth        │────▶│ signUp / signIn  │
│  يفتح /      │     │  (نموذج)       │     │  (Supabase Auth) │
└──────────────┘     └────────────────┘     └────────┬─────────┘
                                                     │
                                     ┌───────────────┴────────┐
                                     ▼                        ▼
                          ┌────────────────────┐    ┌──────────────────┐
                          │ trigger:            │    │ session في       │
                          │ handle_new_user     │    │ localStorage     │
                          │ → profile + role    │    └────────┬─────────┘
                          └────────────────────┘             │
                                                              ▼
                                                    ┌──────────────────┐
                                                    │ AuthProvider     │
                                                    │ يجيب role        │
                                                    └────────┬─────────┘
                                                             ▼
                                                    ┌──────────────────┐
                                                    │  /gallery        │
                                                    └──────────────────┘
```

### 6.2 تدفق رفع عمل

```text
┌──────────────┐
│ اختيار الملف │
└──────┬───────┘
       ▼
┌──────────────────┐
│ detectMediaType  │──❌──▶ toast "نوع غير مدعوم"
│ + حجم <= 50MB    │──❌──▶ toast "الملف كبير"
└──────┬───────────┘
       ▼ ✅
┌────────────────────────┐
│ storage.upload         │
│ (works/<uid>/<uuid>.x) │
└──────┬─────────────────┘
       ▼
┌─────────────────────────────────────┐
│ insert into works                    │
│  status = servant ? approved : pending│
└──────┬───────────────────────────────┘
       ▼
┌─────────────────┐
│ navigate to     │
│ /my-works       │
└─────────────────┘
```

### 6.3 تدفق الموافقة

```text
مخدوم يرفع عمل ──▶ status = pending ──▶ مايبانش في /gallery
                                       └▶ يبان في /pending للخادم
                                       ▼
                             الخادم يوافق (update status='approved')
                                       ▼
                                 يبان في /gallery
```

---

## 7. نقاط الأمان (مهمة للجنة)

1. **RLS مفعّل على كل الجداول** — أي query من الـ client بيتفلتر تلقائياً حسب الـ policies.
2. **الأدوار في جدول منفصل (`user_roles`)** — يمنع privilege escalation (لو حصل مشكلة في policies الـ `profiles`، المهاجم مايقدرش يرقّي نفسه لخادم).
3. **`has_role` في `private` schema + `SECURITY DEFINER`** — الدالة مش مكشوفة من API، وبتشتغل بصلاحيات ثابتة لتفادي recursion.
4. **Storage bucket خاص** — الملفات ما تتفتحش بـ URL مباشر، لازم signed URL مؤقت.
5. **مفاتيح Supabase الجديدة (`sb_publishable_*`)** — opaque strings، مش JWT، الـ client بيتعامل معاها في header `apikey` مش `Authorization`.
6. **`SUPABASE_SERVICE_ROLE_KEY` غير مستخدم في الـ frontend نهائياً** — بيكسر الـ RLS ولازم يفضل server-side بس.
7. **Trigger `handle_new_user`** بيشتغل `SECURITY DEFINER` عشان يقدر يكتب في `user_roles` (اللي user عادي مايقدرش يـ insert فيها).

---

## 8. أسئلة متوقعة من اللجنة + إجابات مختصرة

**س: ليه TanStack Router مش React Router؟**
> Type-safe (كل الروابط والـ params متحقق منها في compile time)، بيدعم SSR و file-based routing، وأسرع في التنقّل بفضل الـ preloading.

**س: إيه فايدة TanStack Query هنا؟**
> بتدير الـ server state (caching, refetching, invalidation) بدل ما نكتب `useEffect + useState` لكل fetch. بتحسّن الأداء بشكل ملحوظ.

**س: ليه Supabase مش Firebase؟**
> Postgres (SQL معياري)، مفتوح المصدر، RLS قوي، وأرخص. Firebase بيستخدم NoSQL واللي أصعب في العلاقات المعقّدة.

**س: إزاي بتتأكد إن المخدوم مايقدرش يوافق على منشور؟**
> الـ RLS policy `Servants update any` بتشترط `has_role(auth.uid(), 'servant')`. لو مخدوم حاول يعمل update لـ `status`، PostgreSQL هترفض العملية.

**س: لو مهاجم بعت request مباشرة للـ API؟**
> نفس الإجابة — الـ RLS بيشتغل على مستوى الـ database، مش الـ client. حتى لو المهاجم عرف مفتاح `anon` بيقدر بس على العمليات المصرّح بيها.

**س: إزاي بتدعم الاتجاهين RTL/LTR؟**
> Tailwind فيه modifiers `rtl:` و `ltr:` + classes `ms-*` `me-*` `start-*` `end-*` (logical properties). و `dir` بيتحدد ديناميكياً من `I18nProvider`.

**س: ليه الصورة الخلفية بـ `fixed` مش `absolute`؟**
> عشان تفضل مكانها لما المستخدم يعمل scroll، مش تتحرك مع المحتوى.

**س: إزاي بتخزّني ملف كبير؟**
> Supabase Storage بيرفع بشكل multipart تلقائياً. الـ Max هنا 50MB (`MAX_SIZE`).

**س: إيه اللي بيحصل لو عمل اتحذف والملف موجود في الـ storage؟**
> في `deleteWork` بنمسح من الـ storage الأول، بعدين من الـ DB. لو حصل خطأ بين الاتنين ممكن يفضل ملف يتيم — ممكن نضيف cron job لتنظيفه لاحقاً.

---

## 9. ملخص سريع

- **موقع** لعرض أعمال المهرجان بدورين (خادم / مخدوم).
- **Frontend:** React + TanStack + Tailwind + shadcn.
- **Backend:** Supabase (Postgres + Auth + Storage) مع RLS.
- **الأمان:** أدوار في جدول منفصل، RLS على كل جدول، storage خاص بـ signed URLs.
- **تجربة مستخدم:** لغتين، ثيمين، بحث، تعليقات، ريأكشنز، رفع صور/PDF/فيديو حتى 50MB.

---

**تم بحمد الله. 🎉**
