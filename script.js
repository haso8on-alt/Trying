// ===== DATA =====
const translations = {
  en: {
    logoMain: "My Personal Shopper",
    logoSub: "SAUDI ARABIA",
    nav: ["Home", "Shop", "Brands", "Offers", "About"],
    heroBadge: "Official Sephora Products",
    heroTitle: ["Your Beauty", "Destination in", "Saudi Arabia"],
    heroHighlight: "Saudi Arabia",
    heroDesc: "Discover the world's finest beauty brands, delivered to your door. Authentic Sephora products with exclusive Saudi pricing.",
    heroShop: "Shop Now",
    heroExplore: "Explore Brands",
    statProducts: "500+",
    statProductsLabel: "Products",
    statBrands: "80+",
    statBrandsLabel: "Brands",
    statDelivery: "24h",
    statDeliveryLabel: "Delivery",
    shopBy: "Shop by Category",
    shopByDesc: "Explore our curated collection of premium beauty products",
    categoriesTag: "Categories",
    productsSectionTag: "Featured Products",
    productsSectionTitle: "Best Sellers",
    productsSectionDesc: "Handpicked favorites loved by our customers",
    filters: ["All", "Makeup", "Skincare", "Fragrance", "Haircare", "Tools"],
    sortBy: "Sort By",
    showing: "Showing",
    products: "products",
    addToCart: "Add to Cart",
    added: "Added!",
    currency: "SAR",
    cartTitle: "Shopping Cart",
    cartEmpty: "Your cart is empty",
    cartEmptySub: "Add some products to get started",
    cartItems: "items",
    cartItem: "item",
    subtotal: "Subtotal",
    shipping: "Shipping",
    free: "Free",
    vat: "VAT (15%)",
    total: "Total",
    checkout: "Checkout",
    checkoutTitle: "Checkout",
    steps: ["Delivery", "Payment", "Review"],
    deliveryInfo: "Delivery Information",
    firstName: "First Name",
    lastName: "Last Name",
    email: "Email Address",
    phone: "Phone Number",
    city: "City",
    district: "District",
    street: "Street Address",
    zipCode: "ZIP Code",
    paymentMethod: "Payment Method",
    creditCard: "Credit Card",
    applePay: "Apple Pay",
    stcPay: "STC Pay",
    mada: "Mada",
    cardNumber: "Card Number",
    cardName: "Cardholder Name",
    expiry: "Expiry Date",
    cvv: "CVV",
    orderSummary: "Order Summary",
    back: "Back",
    next: "Continue",
    placeOrder: "Place Order",
    successTitle: "Order Confirmed!",
    successDesc: "Your order has been placed successfully. You will receive a confirmation SMS shortly.",
    successOrder: "Order ID: #MPS",
    continueShopping: "Continue Shopping",
    promoTag: "Limited Time Offer",
    promoTitle: ["Exclusive", "Beauty Sale", "Up to 30% Off"],
    promoDesc: "Don't miss our biggest beauty sale of the season. Premium products at unbeatable prices.",
    days: "Days",
    hours: "Hours",
    mins: "Mins",
    secs: "Secs",
    brandsTitle: "Featured Brands",
    brandsTag: "Top Brands",
    brandsDesc: "Explore collections from the world's most loved beauty brands",
    search: "Search products...",
    wishlistAdded: "Added to wishlist",
    cartAdded: "Added to cart",
    cities: ["Riyadh", "Jeddah", "Mecca", "Medina", "Dammam", "Khobar", "Tabuk", "Abha"],
    footerDesc: "Your trusted destination for authentic Sephora products in Saudi Arabia. Premium beauty delivered to your door.",
    footerShop: "Shop",
    footerShopLinks: ["Makeup", "Skincare", "Fragrance", "Haircare", "Tools & Brushes"],
    footerHelp: "Help",
    footerHelpLinks: ["Track Order", "Return Policy", "Shipping Info", "Contact Us", "FAQ"],
    footerLegal: "Legal",
    footerLegalLinks: ["Privacy Policy", "Terms of Service", "Cookies", "Sitemap"],
    footerCopy: "© 2025 My Personal Shopper. All rights reserved.",
    marqueeItems: ["FREE SHIPPING OVER 300 SAR", "AUTHENTIC SEPHORA PRODUCTS", "SAME-DAY DELIVERY IN RIYADH", "EASY 30-DAY RETURNS", "COD AVAILABLE"],
  },
  ar: {
    logoMain: "متجري الشخصي",
    logoSub: "المملكة العربية السعودية",
    nav: ["الرئيسية", "المتجر", "الماركات", "العروض", "عن المتجر"],
    heroBadge: "منتجات سيفورا الأصلية",
    heroTitle: ["وجهتك", "للجمال في", "المملكة العربية السعودية"],
    heroHighlight: "المملكة العربية السعودية",
    heroDesc: "اكتشفي أفضل ماركات الجمال العالمية، تُوصَّل إلى بابك. منتجات سيفورا الأصلية بأسعار سعودية حصرية.",
    heroShop: "تسوقي الآن",
    heroExplore: "استكشفي الماركات",
    statProducts: "+500",
    statProductsLabel: "منتج",
    statBrands: "+80",
    statBrandsLabel: "ماركة",
    statDelivery: "24h",
    statDeliveryLabel: "توصيل",
    shopBy: "تسوقي حسب الفئة",
    shopByDesc: "اكتشفي مجموعتنا المنتقاة من منتجات الجمال الفاخرة",
    categoriesTag: "الفئات",
    productsSectionTag: "منتجات مميزة",
    productsSectionTitle: "الأكثر مبيعاً",
    productsSectionDesc: "مفضلات منتقاة تحبها عميلاتنا",
    filters: ["الكل", "مكياج", "عناية بالبشرة", "عطور", "عناية بالشعر", "أدوات"],
    sortBy: "ترتيب حسب",
    showing: "عرض",
    products: "منتجات",
    addToCart: "أضف للسلة",
    added: "تمت الإضافة!",
    currency: "ر.س",
    cartTitle: "سلة التسوق",
    cartEmpty: "سلتك فارغة",
    cartEmptySub: "أضف بعض المنتجات للبدء",
    cartItems: "عناصر",
    cartItem: "عنصر",
    subtotal: "المجموع الفرعي",
    shipping: "الشحن",
    free: "مجاني",
    vat: "ضريبة القيمة المضافة (15%)",
    total: "الإجمالي",
    checkout: "إتمام الشراء",
    checkoutTitle: "إتمام الطلب",
    steps: ["التوصيل", "الدفع", "المراجعة"],
    deliveryInfo: "معلومات التوصيل",
    firstName: "الاسم الأول",
    lastName: "اسم العائلة",
    email: "البريد الإلكتروني",
    phone: "رقم الهاتف",
    city: "المدينة",
    district: "الحي",
    street: "عنوان الشارع",
    zipCode: "الرمز البريدي",
    paymentMethod: "طريقة الدفع",
    creditCard: "بطاقة ائتمان",
    applePay: "Apple Pay",
    stcPay: "STC Pay",
    mada: "مدى",
    cardNumber: "رقم البطاقة",
    cardName: "اسم حامل البطاقة",
    expiry: "تاريخ الانتهاء",
    cvv: "رمز الأمان",
    orderSummary: "ملخص الطلب",
    back: "رجوع",
    next: "متابعة",
    placeOrder: "تأكيد الطلب",
    successTitle: "تم تأكيد طلبك!",
    successDesc: "تم تقديم طلبك بنجاح. ستتلقين رسالة تأكيد على هاتفك قريباً.",
    successOrder: "رقم الطلب: #MPS",
    continueShopping: "مواصلة التسوق",
    promoTag: "عرض لفترة محدودة",
    promoTitle: ["تخفيضات", "الجمال الحصرية", "حتى 30% خصم"],
    promoDesc: "لا تفوتي أكبر تخفيضات الجمال هذا الموسم. منتجات فاخرة بأسعار لا تقاوم.",
    days: "أيام",
    hours: "ساعات",
    mins: "دقائق",
    secs: "ثواني",
    brandsTitle: "الماركات المميزة",
    brandsTag: "أفضل الماركات",
    brandsDesc: "استكشفي مجموعات من أكثر ماركات الجمال حباً في العالم",
    search: "ابحثي عن المنتجات...",
    wishlistAdded: "تمت الإضافة إلى المفضلة",
    cartAdded: "تمت الإضافة إلى السلة",
    cities: ["الرياض", "جدة", "مكة المكرمة", "المدينة المنورة", "الدمام", "الخبر", "تبوك", "أبها"],
    footerDesc: "وجهتك الموثوقة للحصول على منتجات سيفورا الأصلية في المملكة العربية السعودية. جمال فاخر يُوصَّل إلى بابك.",
    footerShop: "تسوق",
    footerShopLinks: ["مكياج", "عناية بالبشرة", "عطور", "عناية بالشعر", "أدوات وفرش"],
    footerHelp: "مساعدة",
    footerHelpLinks: ["تتبع الطلب", "سياسة الإرجاع", "معلومات الشحن", "تواصل معنا", "الأسئلة الشائعة"],
    footerLegal: "قانوني",
    footerLegalLinks: ["سياسة الخصوصية", "شروط الخدمة", "ملفات تعريف الارتباط", "خريطة الموقع"],
    footerCopy: "© 2025 متجري الشخصي. جميع الحقوق محفوظة.",
    marqueeItems: ["شحن مجاني فوق 300 ريال", "منتجات سيفورا الأصلية", "توصيل في نفس اليوم بالرياض", "إرجاع سهل خلال 30 يوم", "الدفع عند الاستلام متاح"],
  }
};

const categories = [
  { id: "all",       icon: "✨", nameEn: "All Products",  nameAr: "كل المنتجات",    count: 48 },
  { id: "makeup",    icon: "💄", nameEn: "Makeup",         nameAr: "مكياج",          count: 16 },
  { id: "skincare",  icon: "🧴", nameEn: "Skincare",       nameAr: "عناية بالبشرة",  count: 14 },
  { id: "fragrance", icon: "🌸", nameEn: "Fragrance",      nameAr: "عطور",           count: 8  },
  { id: "haircare",  icon: "💆", nameEn: "Haircare",       nameAr: "عناية بالشعر",   count: 7  },
  { id: "tools",     icon: "🖌️", nameEn: "Tools & Brushes",nameAr: "أدوات وفرش",     count: 3  },
];

const brands = [
  { name: "Charlotte Tilbury", nameAr: "شارلوت تيلبري", count: 24 },
  { name: "Fenty Beauty",      nameAr: "فينتي بيوتي",    count: 31 },
  { name: "Dior Beauty",       nameAr: "ديور بيوتي",      count: 18 },
  { name: "Tatcha",            nameAr: "تاتشا",           count: 12 },
  { name: "Drunk Elephant",    nameAr: "درانك إليفانت",   count: 15 },
  { name: "YSL Beauty",        nameAr: "إيف سان لوران",  count: 20 },
  { name: "Armani Beauty",     nameAr: "أرماني بيوتي",   count: 17 },
  { name: "La Mer",            nameAr: "لا مير",          count: 9  },
];

// SAR prices (with 25% markup applied already)
const products = [
  // MAKEUP
  { id: 1,  cat: "makeup",    brand: "Charlotte Tilbury", nameEn: "Pillow Talk Lipstick",          nameAr: "أحمر شفاه بيلو توك",           basePrice: 95,  icon: "💄", rating: 4.8, reviews: 2341, badge: "bestseller" },
  { id: 2,  cat: "makeup",    brand: "Fenty Beauty",      nameEn: "Pro Filt'r Foundation",         nameAr: "كريم الأساس برو فيلتر",         basePrice: 175, icon: "🫙", rating: 4.7, reviews: 1893, badge: "new" },
  { id: 3,  cat: "makeup",    brand: "Dior Beauty",       nameEn: "Rouge Dior Lipstick",           nameAr: "أحمر شفاه روج ديور",            basePrice: 185, icon: "💋", rating: 4.9, reviews: 987,  badge: "bestseller" },
  { id: 4,  cat: "makeup",    brand: "YSL Beauty",        nameEn: "Touche Éclat Highlighter",      nameAr: "هايلايتر توش إيكلا",            basePrice: 215, icon: "✨", rating: 4.6, reviews: 1256, badge: null },
  { id: 5,  cat: "makeup",    brand: "Armani Beauty",     nameEn: "Luminous Silk Foundation",      nameAr: "كريم أساس لومينوس سيلك",        basePrice: 220, icon: "🌟", rating: 4.8, reviews: 2109, badge: "bestseller" },
  { id: 6,  cat: "makeup",    brand: "Charlotte Tilbury", nameEn: "Beautiful Skin Foundation",     nameAr: "كريم أساس بيوتيفول سكن",        basePrice: 245, icon: "💅", rating: 4.7, reviews: 876,  badge: "new" },
  { id: 7,  cat: "makeup",    brand: "Fenty Beauty",      nameEn: "Gloss Bomb Lip Luminizer",      nameAr: "غلوس بومب للشفاه",              basePrice: 85,  icon: "👄", rating: 4.5, reviews: 3241, badge: null },
  { id: 8,  cat: "makeup",    brand: "Dior Beauty",       nameEn: "Diorshow Mascara",              nameAr: "ماسكارا ديورشو",                basePrice: 165, icon: "👁️", rating: 4.6, reviews: 1432, badge: null },
  // SKINCARE
  { id: 9,  cat: "skincare",  brand: "Tatcha",            nameEn: "The Dewy Skin Cream",           nameAr: "كريم ديوي سكن الترطيبي",        basePrice: 280, icon: "🧴", rating: 4.9, reviews: 4532, badge: "bestseller" },
  { id: 10, cat: "skincare",  brand: "Drunk Elephant",    nameEn: "T.L.C. Sukari Babyfacial",      nameAr: "قناع سوكاري بيبي فيشل",         basePrice: 310, icon: "🫧", rating: 4.7, reviews: 2198, badge: "new" },
  { id: 11, cat: "skincare",  brand: "La Mer",            nameEn: "Crème de la Mer Moisturizer",   nameAr: "مرطب كريم دي لا مير",           basePrice: 780, icon: "💎", rating: 4.9, reviews: 1876, badge: "bestseller" },
  { id: 12, cat: "skincare",  brand: "Tatcha",            nameEn: "The Rice Wash Cleanser",        nameAr: "غسول رايس ووش",                 basePrice: 195, icon: "🌾", rating: 4.6, reviews: 1543, badge: null },
  { id: 13, cat: "skincare",  brand: "Drunk Elephant",    nameEn: "Protini Polypeptide Cream",     nameAr: "كريم بروتيني بولي ببتيد",       basePrice: 320, icon: "⚗️", rating: 4.8, reviews: 2876, badge: "bestseller" },
  { id: 14, cat: "skincare",  brand: "La Mer",            nameEn: "The Eye Concentrate",           nameAr: "كريم العيون المركّز",           basePrice: 560, icon: "👁️", rating: 4.7, reviews: 987,  badge: null },
  { id: 15, cat: "skincare",  brand: "Tatcha",            nameEn: "The Water Cream",               nameAr: "كريم الماء الخفيف",             basePrice: 260, icon: "💧", rating: 4.7, reviews: 2134, badge: null },
  { id: 16, cat: "skincare",  brand: "Drunk Elephant",    nameEn: "C-Firma Fresh Vitamin C Serum", nameAr: "سيروم فيتامين C سي فيرما",      basePrice: 290, icon: "🍊", rating: 4.6, reviews: 1765, badge: "new" },
  // FRAGRANCE
  { id: 17, cat: "fragrance", brand: "Dior Beauty",       nameEn: "Miss Dior Blooming Bouquet",    nameAr: "عطر Miss Dior Blooming",        basePrice: 425, icon: "🌹", rating: 4.8, reviews: 3421, badge: "bestseller" },
  { id: 18, cat: "fragrance", brand: "YSL Beauty",        nameEn: "Black Opium EDP",               nameAr: "عطر بلاك أوبيوم",               basePrice: 395, icon: "🖤", rating: 4.9, reviews: 4123, badge: "bestseller" },
  { id: 19, cat: "fragrance", brand: "Armani Beauty",     nameEn: "Si Eau de Parfum",              nameAr: "عطر Si أرماني",                 basePrice: 450, icon: "🌺", rating: 4.7, reviews: 1987, badge: null },
  { id: 20, cat: "fragrance", brand: "Dior Beauty",       nameEn: "J'adore EDP",                  nameAr: "عطر جادور ديور",                basePrice: 475, icon: "✨", rating: 4.8, reviews: 2654, badge: null },
  { id: 21, cat: "fragrance", brand: "YSL Beauty",        nameEn: "Libre Eau de Parfum",           nameAr: "عطر ليبر إيف سان لوران",        basePrice: 415, icon: "💜", rating: 4.7, reviews: 1432, badge: "new" },
  // HAIRCARE
  { id: 22, cat: "haircare",  brand: "Charlotte Tilbury", nameEn: "Hair Elixir Serum",             nameAr: "سيروم إكسير للشعر",             basePrice: 145, icon: "💫", rating: 4.6, reviews: 876,  badge: null },
  { id: 23, cat: "haircare",  brand: "Tatcha",            nameEn: "Scalp Harmony Treatment",       nameAr: "علاج توازن فروة الرأس",         basePrice: 235, icon: "🌿", rating: 4.5, reviews: 654,  badge: "new" },
  { id: 24, cat: "haircare",  brand: "Drunk Elephant",    nameEn: "The Cocomino Marula Hair Mask", nameAr: "قناع شعر كوكومينو ماروالا",     basePrice: 275, icon: "🥥", rating: 4.7, reviews: 987,  badge: null },
  // TOOLS
  { id: 25, cat: "tools",     brand: "Charlotte Tilbury", nameEn: "Magic Vanity Mirror",           nameAr: "مرآة ماجيك فانيتي",            basePrice: 375, icon: "🪞", rating: 4.8, reviews: 1234, badge: "bestseller" },
  { id: 26, cat: "tools",     brand: "Fenty Beauty",      nameEn: "Full-Bodied Foundation Brush",  nameAr: "فرشاة كريم الأساس المكثفة",    basePrice: 130, icon: "🖌️", rating: 4.6, reviews: 765,  badge: null },
  { id: 27, cat: "tools",     brand: "Armani Beauty",     nameEn: "Pro Blending Sponge Set",       nameAr: "مجموعة إسفنجات بروفشنل",       basePrice: 95,  icon: "🧽", rating: 4.5, reviews: 543,  badge: "new" },
];

// Apply 25% markup
products.forEach(p => {
  p.displayPrice = Math.ceil(p.basePrice * 1.25);
  p.originalPrice = p.basePrice;
});

// ===== STATE =====
let lang = "en";
let cart = [];
let wishlist = [];
let activeCategory = "all";
let activeFilter = "all";
let checkoutStep = 1;
let selectedPayment = "card";
let countdownInterval = null;
let cartOpen = false;
let checkoutOpen = false;
let searchOpen = false;

// ===== HELPERS =====
function t(key) { return translations[lang][key]; }
function isRTL() { return lang === "ar"; }

function formatPrice(price) {
  return `${price.toLocaleString()} ${t("currency")}`;
}

function getStars(rating) {
  const full = Math.floor(rating);
  const half = rating % 1 >= 0.5;
  return "★".repeat(full) + (half ? "½" : "") + "☆".repeat(5 - full - (half ? 1 : 0));
}

// ===== RENDER =====
function render() {
  document.documentElement.lang = lang;
  document.body.classList.toggle("rtl", isRTL());
  renderHeader();
  renderHero();
  renderMarquee();
  renderCategories();
  renderProducts();
  renderPromo();
  renderBrands();
  renderFooter();
  renderCart();
  renderCartBadge();
}

function renderHeader() {
  const T = translations[lang];
  document.querySelector(".logo-main").textContent = T.logoMain;
  document.querySelector(".logo-sub").textContent = T.logoSub;

  const navEl = document.querySelector(".nav");
  navEl.innerHTML = T.nav.map((n, i) =>
    `<a href="#" class="nav-link${i === 0 ? " active" : ""}" onclick="scrollToSection(event, ${i})">${n}</a>`
  ).join("");

  document.querySelector(".lang-btn").textContent = lang === "en" ? "العربية" : "English";

  const mobileNav = document.querySelector(".mobile-nav");
  mobileNav.innerHTML = `
    <button class="mobile-nav-close" onclick="closeMobileNav()">✕</button>
    ${T.nav.map((n, i) => `<a href="#" class="mobile-nav-link" onclick="scrollToSection(event,${i});closeMobileNav()">${n}</a>`).join("")}
  `;
}

function renderHero() {
  const T = translations[lang];
  document.querySelector(".hero-badge span:last-child").textContent = T.heroBadge;
  const titleEl = document.querySelector(".hero-title");
  titleEl.innerHTML = T.heroTitle.map((line, i) =>
    i === T.heroTitle.length - 1
      ? `<span class="highlight">${line}</span>`
      : `${line}<br>`
  ).join("");
  document.querySelector(".hero-desc").textContent = T.heroDesc;
  document.querySelectorAll(".hero-cta-shop").forEach(el => el.textContent = T.heroShop);
  document.querySelectorAll(".hero-cta-explore").forEach(el => el.textContent = T.heroExplore);

  const stats = document.querySelectorAll(".stat-item");
  const statData = [
    [T.statProducts, T.statProductsLabel],
    [T.statBrands, T.statBrandsLabel],
    [T.statDelivery, T.statDeliveryLabel],
  ];
  stats.forEach((s, i) => {
    s.querySelector(".stat-value").textContent = statData[i][0];
    s.querySelector(".stat-label").textContent = statData[i][1];
  });
}

function renderMarquee() {
  const T = translations[lang];
  const items = [...T.marqueeItems, ...T.marqueeItems];
  const track = document.querySelector(".marquee-track");
  track.innerHTML = items.map(item =>
    `<span class="marquee-item">${item}<span class="marquee-divider">◆</span></span>`
  ).join("");
}

function renderCategories() {
  const T = translations[lang];
  document.querySelector(".categories-section .section-tag").textContent = T.categoriesTag;
  document.querySelector(".categories-section .section-title").textContent = T.shopBy;
  document.querySelector(".categories-section .section-desc").textContent = T.shopByDesc;

  const grid = document.querySelector(".categories-grid");
  grid.innerHTML = categories.map(c => `
    <div class="category-card${activeCategory === c.id ? " active" : ""}" onclick="setCategory('${c.id}')">
      <span class="category-icon">${c.icon}</span>
      <div class="category-name">${lang === "en" ? c.nameEn : c.nameAr}</div>
      <div class="category-count">${c.count} ${lang === "en" ? "products" : "منتج"}</div>
    </div>
  `).join("");
}

function renderProducts() {
  const T = translations[lang];
  document.querySelector(".products-section .section-tag").textContent = T.productsSectionTag;
  document.querySelector(".products-section .section-title").textContent = T.productsSectionTitle;
  document.querySelector(".products-section .section-desc").textContent = T.productsSectionDesc;

  const filterBtns = document.querySelector(".products-filters");
  filterBtns.innerHTML = T.filters.map((f, i) => {
    const filterIds = ["all", "makeup", "skincare", "fragrance", "haircare", "tools"];
    return `<button class="filter-btn${activeFilter === filterIds[i] ? " active" : ""}" onclick="setFilter('${filterIds[i]}')">${f}</button>`;
  }).join("");

  const filtered = products.filter(p => {
    const catMatch = activeCategory === "all" || p.cat === activeCategory;
    const filterMatch = activeFilter === "all" || p.cat === activeFilter;
    return catMatch && filterMatch;
  });

  document.querySelector(".products-count").innerHTML =
    `${T.showing} <strong>${filtered.length}</strong> ${T.products}`;

  const grid = document.querySelector(".products-grid");
  grid.innerHTML = filtered.map(p => {
    const inCart = cart.some(c => c.id === p.id);
    const inWish = wishlist.includes(p.id);
    const badgeHtml = p.badge
      ? `<span class="product-badge${p.badge === "new" ? " new" : p.badge === "sale" ? " sale" : ""}">${
          p.badge === "bestseller" ? (lang === "en" ? "Best Seller" : "الأكثر مبيعاً") :
          p.badge === "new" ? (lang === "en" ? "New" : "جديد") : p.badge
        }</span>`
      : "";
    return `
    <div class="product-card" data-id="${p.id}">
      <div class="product-img-wrap">
        <div class="product-img-placeholder">${p.icon}</div>
        ${badgeHtml}
        <div class="product-actions">
          <button class="action-btn" onclick="toggleWishlist(${p.id})" title="${lang === "en" ? "Wishlist" : "المفضلة"}">
            ${inWish ? "❤️" : "🤍"}
          </button>
          <button class="action-btn" onclick="quickView(${p.id})" title="${lang === "en" ? "Quick View" : "عرض سريع"}">👁️</button>
        </div>
      </div>
      <div class="product-info">
        <div class="product-brand">${p.brand}</div>
        <div class="product-name">${lang === "en" ? p.nameEn : p.nameAr}</div>
        <div class="product-rating">
          <span class="stars">${getStars(p.rating)}</span>
          <span class="rating-count">(${p.reviews.toLocaleString()})</span>
        </div>
        <div class="product-price">
          <span class="price-current">${p.displayPrice.toLocaleString()}</span>
          <span class="price-currency">${t("currency")}</span>
          <span class="price-original">${p.originalPrice.toLocaleString()} ${t("currency")}</span>
        </div>
        <button class="add-to-cart-btn${inCart ? " added" : ""}" onclick="addToCart(${p.id})">
          ${inCart ? t("added") : t("addToCart")}
        </button>
      </div>
    </div>`;
  }).join("");
}

function renderPromo() {
  const T = translations[lang];
  document.querySelector(".promo-tag span:last-child").textContent = T.promoTag;
  const promoTitle = document.querySelector(".promo-title");
  promoTitle.innerHTML = T.promoTitle.map((line, i) =>
    i === 1 ? `<span class="gold">${line}</span><br>` : `${line}<br>`
  ).join("");
  document.querySelector(".promo-desc").textContent = T.promoDesc;

  const labels = document.querySelectorAll(".countdown-label");
  const labelKeys = ["days", "hours", "mins", "secs"];
  labels.forEach((l, i) => { l.textContent = T[labelKeys[i]]; });
}

function renderBrands() {
  const T = translations[lang];
  document.querySelector(".brands-section .section-tag").textContent = T.brandsTag;
  document.querySelector(".brands-section .section-title").textContent = T.brandsTitle;
  document.querySelector(".brands-section .section-desc").textContent = T.brandsDesc;

  const grid = document.querySelector(".brands-grid");
  grid.innerHTML = brands.map(b => `
    <div class="brand-card" onclick="filterByBrand('${b.name}')">
      <div class="brand-logo">${lang === "en" ? b.name : b.nameAr}</div>
      <div class="brand-count">${b.count} ${lang === "en" ? "products" : "منتج"}</div>
    </div>
  `).join("");
}

function renderFooter() {
  const T = translations[lang];
  document.querySelector(".footer-brand .logo-main").textContent = T.logoMain;
  document.querySelector(".footer-brand .logo-sub").textContent = T.logoSub;
  document.querySelector(".footer-brand-desc").textContent = T.footerDesc;
  document.querySelector(".footer-copy").textContent = T.footerCopy;

  document.querySelector(".footer-col-shop .footer-col-title").textContent = T.footerShop;
  document.querySelector(".footer-col-shop .footer-links").innerHTML =
    T.footerShopLinks.map(l => `<li><a href="#">${l}</a></li>`).join("");

  document.querySelector(".footer-col-help .footer-col-title").textContent = T.footerHelp;
  document.querySelector(".footer-col-help .footer-links").innerHTML =
    T.footerHelpLinks.map(l => `<li><a href="#">${l}</a></li>`).join("");

  document.querySelector(".footer-col-legal .footer-col-title").textContent = T.footerLegal;
  document.querySelector(".footer-col-legal .footer-links").innerHTML =
    T.footerLegalLinks.map(l => `<li><a href="#">${l}</a></li>`).join("");
}

function renderCart() {
  const T = translations[lang];
  document.querySelector(".cart-title").textContent = T.cartTitle;
  document.querySelector(".checkout-btn").textContent = T.checkout;

  const itemsEl = document.querySelector(".cart-items");
  if (cart.length === 0) {
    itemsEl.innerHTML = `
      <div class="cart-empty">
        <span class="cart-empty-icon">🛒</span>
        <span class="cart-empty-text">${T.cartEmpty}</span>
        <span class="cart-empty-sub">${T.cartEmptySub}</span>
      </div>`;
    document.querySelector(".cart-item-count").textContent = "";
  } else {
    const count = cart.reduce((s, i) => s + i.qty, 0);
    document.querySelector(".cart-item-count").textContent =
      `${count} ${count === 1 ? T.cartItem : T.cartItems}`;
    itemsEl.innerHTML = cart.map(ci => {
      const p = products.find(p => p.id === ci.id);
      return `
      <div class="cart-item">
        <div class="cart-item-img">${p.icon}</div>
        <div class="cart-item-details">
          <div class="cart-item-brand">${p.brand}</div>
          <div class="cart-item-name">${lang === "en" ? p.nameEn : p.nameAr}</div>
          <div class="cart-item-controls">
            <button class="qty-btn" onclick="updateQty(${p.id}, -1)">−</button>
            <span class="qty-value">${ci.qty}</span>
            <button class="qty-btn" onclick="updateQty(${p.id}, 1)">+</button>
            <button class="cart-item-remove" onclick="removeFromCart(${p.id})">🗑️</button>
          </div>
        </div>
        <div class="cart-item-price">${(p.displayPrice * ci.qty).toLocaleString()} ${T.currency}</div>
      </div>`;
    }).join("");
  }

  const subtotal = cart.reduce((s, ci) => {
    const p = products.find(p => p.id === ci.id);
    return s + p.displayPrice * ci.qty;
  }, 0);
  const vat = Math.round(subtotal * 0.15);
  const total = subtotal + vat;

  document.querySelector(".cart-subtotal").textContent = `${subtotal.toLocaleString()} ${T.currency}`;
  document.querySelector(".cart-vat").textContent = `${vat.toLocaleString()} ${T.currency}`;
  document.querySelector(".cart-total").textContent = `${total.toLocaleString()} ${T.currency}`;
  document.querySelector(".cart-shipping-val").textContent = subtotal >= 300 ? T.free : `25 ${T.currency}`;

  document.querySelector(".cart-summary-row .cart-subtotal-label").textContent = T.subtotal;
  document.querySelector(".cart-summary-row .cart-shipping-label").textContent = T.shipping;
  document.querySelector(".cart-summary-row .cart-vat-label").textContent = T.vat;
  document.querySelector(".cart-summary-row.total .cart-total-label").textContent = T.total;
}

function renderCartBadge() {
  const count = cart.reduce((s, i) => s + i.qty, 0);
  const badge = document.querySelector(".cart-badge");
  badge.textContent = count;
  badge.classList.toggle("visible", count > 0);
}

// ===== ACTIONS =====
function toggleLang() {
  lang = lang === "en" ? "ar" : "en";
  render();
  renderCheckoutModal();
}

function setCategory(id) {
  activeCategory = id;
  activeFilter = id === "all" ? "all" : id;
  render();
  document.querySelector(".products-section").scrollIntoView({ behavior: "smooth", block: "start" });
}

function setFilter(id) {
  activeFilter = id;
  if (id !== "all") activeCategory = "all";
  renderCategories();
  renderProducts();
}

function addToCart(id) {
  const existing = cart.find(c => c.id === id);
  if (existing) {
    existing.qty++;
  } else {
    cart.push({ id, qty: 1 });
  }
  renderProducts();
  renderCart();
  renderCartBadge();
  const p = products.find(p => p.id === id);
  showToast(`✅ ${lang === "en" ? p.nameEn : p.nameAr} — ${t("cartAdded")}`);
}

function removeFromCart(id) {
  cart = cart.filter(c => c.id !== id);
  renderCart();
  renderCartBadge();
  renderProducts();
}

function updateQty(id, delta) {
  const item = cart.find(c => c.id === id);
  if (!item) return;
  item.qty += delta;
  if (item.qty <= 0) removeFromCart(id);
  else { renderCart(); renderCartBadge(); }
}

function toggleWishlist(id) {
  if (wishlist.includes(id)) {
    wishlist = wishlist.filter(w => w !== id);
  } else {
    wishlist.push(id);
    showToast(`❤️ ${t("wishlistAdded")}`);
  }
  renderProducts();
}

function quickView(id) {
  addToCart(id);
}

function filterByBrand(brandName) {
  activeCategory = "all";
  activeFilter = "all";
  renderProducts();
  document.querySelector(".products-section").scrollIntoView({ behavior: "smooth" });
}

// ===== CART SIDEBAR =====
function openCart() {
  cartOpen = true;
  document.querySelector(".cart-overlay").classList.add("open");
  document.querySelector(".cart-sidebar").classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeCart() {
  cartOpen = false;
  document.querySelector(".cart-overlay").classList.remove("open");
  document.querySelector(".cart-sidebar").classList.remove("open");
  document.body.style.overflow = "";
}

// ===== CHECKOUT =====
function openCheckout() {
  if (cart.length === 0) return;
  closeCart();
  checkoutStep = 1;
  checkoutOpen = true;
  document.querySelector(".modal-overlay").classList.add("open");
  document.body.style.overflow = "hidden";
  renderCheckoutModal();
}

function closeCheckout() {
  checkoutOpen = false;
  document.querySelector(".modal-overlay").classList.remove("open");
  document.body.style.overflow = "";
}

function renderCheckoutModal() {
  if (!checkoutOpen) return;
  const T = translations[lang];
  const modal = document.querySelector(".modal");

  const subtotal = cart.reduce((s, ci) => {
    const p = products.find(p => p.id === ci.id);
    return s + p.displayPrice * ci.qty;
  }, 0);
  const vat = Math.round(subtotal * 0.15);
  const shipping = subtotal >= 300 ? 0 : 25;
  const total = subtotal + vat + shipping;

  if (checkoutStep === 4) {
    // Success
    modal.innerHTML = `
      <div class="modal-header"><span></span><button class="modal-close" onclick="closeCheckoutSuccess()">✕</button></div>
      <div class="modal-body">
        <div class="success-screen">
          <span class="success-icon">🎉</span>
          <h2 class="success-title">${T.successTitle}</h2>
          <p class="success-desc">${T.successDesc}</p>
          <p class="success-order">${T.successOrder}${Math.random().toString(36).substr(2, 8).toUpperCase()}</p>
          <button class="btn-primary" onclick="closeCheckoutSuccess()" style="display:inline-block;padding:14px 32px;">${T.continueShopping}</button>
        </div>
      </div>`;
    return;
  }

  const orderItemsHtml = cart.map(ci => {
    const p = products.find(p => p.id === ci.id);
    return `
    <div class="order-item-mini">
      <span class="order-item-icon">${p.icon}</span>
      <span class="order-item-name">${lang === "en" ? p.nameEn : p.nameAr}</span>
      <span class="order-item-qty">×${ci.qty}</span>
      <span class="order-item-price">${(p.displayPrice * ci.qty).toLocaleString()} ${T.currency}</span>
    </div>`;
  }).join("");

  const citiesOptions = T.cities.map(c => `<option>${c}</option>`).join("");

  let stepContent = "";

  if (checkoutStep === 1) {
    stepContent = `
      <div class="form-section">
        <div class="form-section-title">${T.deliveryInfo}</div>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">${T.firstName}</label>
            <input class="form-input" type="text" id="firstName" placeholder="${lang === "en" ? "Sarah" : "سارة"}">
          </div>
          <div class="form-group">
            <label class="form-label">${T.lastName}</label>
            <input class="form-input" type="text" id="lastName" placeholder="${lang === "en" ? "Al-Rashidi" : "الراشدي"}">
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">${T.email}</label>
            <input class="form-input" type="email" id="email" placeholder="${lang === "en" ? "sarah@email.com" : "sarah@email.com"}">
          </div>
          <div class="form-group">
            <label class="form-label">${T.phone}</label>
            <input class="form-input" type="tel" id="phone" placeholder="+966 5X XXX XXXX">
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">${T.city}</label>
            <select class="form-select" id="city">${citiesOptions}</select>
          </div>
          <div class="form-group">
            <label class="form-label">${T.district}</label>
            <input class="form-input" type="text" id="district" placeholder="${lang === "en" ? "Al Malaz" : "الملز"}">
          </div>
        </div>
        <div class="form-row full">
          <div class="form-group">
            <label class="form-label">${T.street}</label>
            <input class="form-input" type="text" id="street" placeholder="${lang === "en" ? "King Fahd Road" : "طريق الملك فهد"}">
          </div>
        </div>
      </div>`;
  } else if (checkoutStep === 2) {
    stepContent = `
      <div class="form-section">
        <div class="form-section-title">${T.paymentMethod}</div>
        <div class="payment-methods">
          <button class="payment-method${selectedPayment === "card" ? " active" : ""}" onclick="selectPayment('card')">
            <span class="payment-method-icon">💳</span>${T.creditCard}
          </button>
          <button class="payment-method${selectedPayment === "apple" ? " active" : ""}" onclick="selectPayment('apple')">
            <span class="payment-method-icon"></span>${T.applePay}
          </button>
          <button class="payment-method${selectedPayment === "stc" ? " active" : ""}" onclick="selectPayment('stc')">
            <span class="payment-method-icon">📱</span>${T.stcPay}
          </button>
          <button class="payment-method${selectedPayment === "mada" ? " active" : ""}" onclick="selectPayment('mada')">
            <span class="payment-method-icon">🏦</span>${T.mada}
          </button>
        </div>
        ${selectedPayment === "card" ? `
        <div class="card-icons">
          <span class="card-icon">💳</span>
          <span class="card-icon">🏦</span>
        </div>
        <div class="form-row full">
          <div class="form-group">
            <label class="form-label">${T.cardNumber}</label>
            <input class="form-input" type="text" placeholder="XXXX XXXX XXXX XXXX" maxlength="19" oninput="formatCard(this)">
          </div>
        </div>
        <div class="form-row full">
          <div class="form-group">
            <label class="form-label">${T.cardName}</label>
            <input class="form-input" type="text" placeholder="${lang === "en" ? "SARAH AL-RASHIDI" : "سارة الراشدي"}">
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">${T.expiry}</label>
            <input class="form-input" type="text" placeholder="MM/YY" maxlength="5" oninput="formatExpiry(this)">
          </div>
          <div class="form-group">
            <label class="form-label">${T.cvv}</label>
            <input class="form-input" type="text" placeholder="123" maxlength="3">
          </div>
        </div>` : `
        <div style="text-align:center;padding:40px 20px;color:var(--gray);">
          <div style="font-size:48px;margin-bottom:12px;">${selectedPayment === "apple" ? "" : selectedPayment === "stc" ? "📱" : "🏦"}</div>
          <div style="font-size:15px;font-weight:600;">${lang === "en" ? "You will be redirected to complete payment" : "سيتم توجيهك لإتمام الدفع"}</div>
        </div>`}
      </div>`;
  } else if (checkoutStep === 3) {
    stepContent = `
      <div class="order-summary-mini">
        <div class="order-summary-mini-title">${T.orderSummary}</div>
        ${orderItemsHtml}
        <div style="margin-top:12px;border-top:1px solid rgba(0,0,0,0.08);padding-top:12px;">
          <div class="order-total-row">
            <span>${T.subtotal}</span><span>${subtotal.toLocaleString()} ${T.currency}</span>
          </div>
          <div class="order-total-row">
            <span>${T.shipping}</span><span>${shipping === 0 ? T.free : `${shipping} ${T.currency}`}</span>
          </div>
          <div class="order-total-row">
            <span>${T.vat}</span><span>${vat.toLocaleString()} ${T.currency}</span>
          </div>
          <div class="order-total-row final">
            <span>${T.total}</span><span>${total.toLocaleString()} ${T.currency}</span>
          </div>
        </div>
      </div>`;
  }

  modal.innerHTML = `
    <div class="modal-header">
      <h2 class="modal-title">${T.checkoutTitle}</h2>
      <button class="modal-close" onclick="closeCheckout()">✕</button>
    </div>
    <div class="modal-body">
      <div class="checkout-steps">
        ${T.steps.map((s, i) => `
          <div class="checkout-step${checkoutStep === i+1 ? " active" : checkoutStep > i+1 ? " done" : ""}">
            ${checkoutStep > i+1 ? "✓ " : ""}${s}
          </div>`).join("")}
      </div>
      ${stepContent}
    </div>
    <div class="modal-footer">
      ${checkoutStep > 1 ? `<button class="btn-back" onclick="prevStep()">${T.back}</button>` : ""}
      <button class="btn-next" onclick="nextStep()">
        ${checkoutStep === 3 ? T.placeOrder : T.next}
      </button>
    </div>`;
}

function selectPayment(method) {
  selectedPayment = method;
  renderCheckoutModal();
}

function nextStep() {
  if (checkoutStep < 3) { checkoutStep++; renderCheckoutModal(); }
  else { checkoutStep = 4; renderCheckoutModal(); cart = []; renderCartBadge(); }
}

function prevStep() {
  if (checkoutStep > 1) { checkoutStep--; renderCheckoutModal(); }
}

function closeCheckoutSuccess() {
  closeCheckout();
  renderCart();
  renderProducts();
}

function formatCard(input) {
  let v = input.value.replace(/\D/g, "").substring(0, 16);
  input.value = v.replace(/(.{4})/g, "$1 ").trim();
}

function formatExpiry(input) {
  let v = input.value.replace(/\D/g, "").substring(0, 4);
  if (v.length >= 2) v = v.substring(0, 2) + "/" + v.substring(2);
  input.value = v;
}

// ===== SEARCH =====
function openSearch() {
  searchOpen = true;
  document.querySelector(".search-overlay").classList.add("open");
  document.getElementById("searchInput").value = "";
  document.querySelector(".search-results").innerHTML = "";
  setTimeout(() => document.getElementById("searchInput").focus(), 100);
}

function closeSearch() {
  searchOpen = false;
  document.querySelector(".search-overlay").classList.remove("open");
}

function handleSearch(query) {
  const resultsEl = document.querySelector(".search-results");
  if (!query.trim()) { resultsEl.innerHTML = ""; return; }

  const results = products.filter(p =>
    (lang === "en" ? p.nameEn : p.nameAr).toLowerCase().includes(query.toLowerCase()) ||
    p.brand.toLowerCase().includes(query.toLowerCase())
  ).slice(0, 6);

  if (results.length === 0) {
    resultsEl.innerHTML = `<div style="padding:20px;text-align:center;color:var(--gray);font-size:14px;">${lang === "en" ? "No results found" : "لا توجد نتائج"}</div>`;
    return;
  }

  resultsEl.innerHTML = results.map(p => `
    <div class="search-result-item" onclick="addToCart(${p.id});closeSearch()">
      <span class="search-result-icon">${p.icon}</span>
      <div class="search-result-info">
        <div class="search-result-name">${lang === "en" ? p.nameEn : p.nameAr}</div>
        <div class="search-result-brand">${p.brand}</div>
      </div>
      <span class="search-result-price">${p.displayPrice.toLocaleString()} ${t("currency")}</span>
    </div>`).join("");
}

// ===== COUNTDOWN =====
function startCountdown() {
  const end = new Date();
  end.setHours(end.getHours() + 47, end.getMinutes() + 30, end.getSeconds() + 0);

  function update() {
    const now = new Date();
    const diff = end - now;
    if (diff <= 0) { clearInterval(countdownInterval); return; }

    const days  = Math.floor(diff / 86400000);
    const hours = Math.floor((diff % 86400000) / 3600000);
    const mins  = Math.floor((diff % 3600000) / 60000);
    const secs  = Math.floor((diff % 60000) / 1000);

    const nums = document.querySelectorAll(".countdown-num");
    if (nums[0]) nums[0].textContent = String(days).padStart(2, "0");
    if (nums[1]) nums[1].textContent = String(hours).padStart(2, "0");
    if (nums[2]) nums[2].textContent = String(mins).padStart(2, "0");
    if (nums[3]) nums[3].textContent = String(secs).padStart(2, "0");
  }

  update();
  countdownInterval = setInterval(update, 1000);
}

// ===== TOAST =====
function showToast(message) {
  const container = document.querySelector(".toast-container");
  const toast = document.createElement("div");
  toast.className = "toast";
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3200);
}

// ===== MOBILE NAV =====
function openMobileNav() {
  document.querySelector(".mobile-nav").classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeMobileNav() {
  document.querySelector(".mobile-nav").classList.remove("open");
  document.body.style.overflow = "";
}

function scrollToSection(e, idx) {
  e.preventDefault();
  const sections = ["#hero", "#categories", "#products", "#promo", "#brands"];
  const target = document.querySelector(sections[idx] || "#hero");
  if (target) target.scrollIntoView({ behavior: "smooth" });
}

// ===== KEYBOARD =====
document.addEventListener("keydown", e => {
  if (e.key === "Escape") {
    if (searchOpen) closeSearch();
    else if (checkoutOpen) closeCheckout();
    else if (cartOpen) closeCart();
  }
});

// ===== INIT =====
document.addEventListener("DOMContentLoaded", () => {
  render();
  startCountdown();

  // Hero card products
  const featuredIds = [1, 9, 17, 3];
  const heroCards = document.querySelectorAll(".hero-card");
  heroCards.forEach((card, i) => {
    const p = products[featuredIds[i] - 1];
    if (p) {
      card.querySelector(".hero-card-img").textContent = p.icon;
      card.querySelector(".hero-card-name").textContent = lang === "en" ? p.nameEn : p.nameAr;
      card.querySelector(".hero-card-price").textContent = `${p.displayPrice.toLocaleString()} ${t("currency")}`;
    }
  });
});
