const APP_ROOT = "/Users/devangsonawane/paycal";

export default {
  appRoot: APP_ROOT,
  bundleId: "com.devangsonawane.paycal",
  android: {
    appPath: `${APP_ROOT}/build/app/outputs/flutter-apk/app-release.apk`,
    applicationId: "com.devangsonawane.paycal",
  },
  devices: ["pixel-10-pro"],
  locales: ["en-US"],
  appearance: "light",
  theme: {
    background: "linear-gradient(155deg, #D8FF00 0%, #F0477F 52%, #9B70F2 100%)",
    headlineColor: "#0A0A0A",
    subheadColor: "#0A0A0A",
    fontFamily: '"Bricolage Grotesque", system-ui, sans-serif',
    copyHeightRatio: 0.24,
    deviceWidthRatio: 0.84,
    template: "dynamic",
  },
  store: {
    name: "Tabbb",
    subtitle: { "en-US": "Split bills. Keep the vibes." },
    developer: "Tabbb",
    category: "Finance",
    rating: 4.8,
    ratingCount: "Freshly dropped",
    ageRating: "4+",
    price: "Free",
    description: {
      "en-US": "Tabbb keeps shared spending simple for your crib, crew, and every plan in between.",
    },
  },
  scenes: [
    {
      kind: "screenshot",
      id: "home",
      flow: "store-01-home",
      headline: { "en-US": "Keep the tab moving" },
      subhead: { "en-US": "See every crib, balance, and next move at a glance." },
    },
    {
      kind: "screenshot",
      id: "cribs",
      flow: "store-02-cribs",
      headline: { "en-US": "One tab per crib" },
      subhead: { "en-US": "Home, trips, and every group in the group chat." },
    },
    {
      kind: "screenshot",
      id: "detail",
      flow: "store-03-detail",
      headline: { "en-US": "Split it your way" },
      subhead: { "en-US": "Keep the receipts, shares, and crew all together." },
    },
    {
      kind: "screenshot",
      id: "activity",
      flow: "store-04-activity",
      headline: { "en-US": "No more who-paid?" },
      subhead: { "en-US": "Every move stays clear for the whole crew." },
    },
    {
      kind: "screenshot",
      id: "profile",
      flow: "store-05-profile",
      headline: { "en-US": "Your money, your vibe" },
      subhead: { "en-US": "Make the shared-money routine feel like yours." },
    },
  ],
};
