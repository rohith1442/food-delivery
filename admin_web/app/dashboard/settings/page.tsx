"use client";

import axios from "axios";
import {
  FormEvent,
  useCallback,
  useEffect,
  useState,
} from "react";

import { api } from "@/lib/api";

type PromoBanner = {
  enabled: boolean;
  title: string;
  subtitle: string;
  imageUrl: string;
  actionType: "NONE" | "MODULE" | "CATEGORY";
  actionValue: string;
};

interface Settings {
  deliveryFee: number;
  minimumOrder: number;
  maintenanceMode: boolean;

  customerMinVersion: string;
  customerForceUpdate: boolean;

  merchantMinVersion: string;
  merchantForceUpdate: boolean;

  deliveryMinVersion: string;
  deliveryForceUpdate: boolean;

  appName: string;
  shortName: string;
  tagline: string;
  logoUrl: string;

  primaryColor: string;
  secondaryColor: string;
  accentColor: string;

  currencySymbol: string;
  supportPhone: string;
  deliveryPromiseText: string;
  content: ContentSettings;
  payments: {
    merchantCommission: { type: "PERCENTAGE" | "FIXED"; value: number };
    riderEarning: { baseAmount: number; perKmAmount: number; minimumAmount: number };
    settlement: { merchantEnabled: boolean; riderPayoutEnabled: boolean; riderPayoutFrequency: "DAILY" | "WEEKLY" | "MANUAL" };
  };

  home: {
    enabledModules: string[];
    sections: Array<{
      id: "modules" | "promo" | "categories" | "nearby";
      enabled: boolean;
      sortOrder: number;
    }>;
    promoBanners: PromoBanner[];
    promoBanner?: PromoBanner;
  };

  updatedAt?: string;
}

interface LegalContent { title: string; content: string; version: string; isEnabled: boolean; }
interface ContentSettings {
  terms: LegalContent; privacy: LegalContent; refundPolicy: LegalContent; deliveryPolicy: LegalContent;
  about: { title: string; content: string; isEnabled: boolean };
  support: { title: string; content: string; phone: string; email: string; whatsapp: string; workingHours: string; isEnabled: boolean };
  permissions: { title: string; location: string; notifications: string; camera: string; photos: string; isEnabled: boolean };
}

const defaultContent: ContentSettings = {
  terms: { title: "Terms & Conditions", content: "", version: "1.0", isEnabled: true }, privacy: { title: "Privacy Policy", content: "", version: "1.0", isEnabled: true }, refundPolicy: { title: "Refund & Cancellation Policy", content: "", version: "1.0", isEnabled: true }, deliveryPolicy: { title: "Delivery Policy", content: "", version: "1.0", isEnabled: true }, about: { title: "About Us", content: "", isEnabled: true }, support: { title: "Contact Support", content: "", phone: "", email: "", whatsapp: "", workingHours: "", isEnabled: true }, permissions: { title: "App Permissions", location: "Location is used to determine service availability and delivery address.", notifications: "Notifications are used for order and delivery updates.", camera: "", photos: "", isEnabled: true },
};

const defaultSettings: Settings = {
  deliveryFee: 40,
  minimumOrder: 0,
  maintenanceMode: false,

  customerMinVersion: "1.0.0",
  customerForceUpdate: false,

  merchantMinVersion: "1.0.0",
  merchantForceUpdate: false,

  deliveryMinVersion: "1.0.0",
  deliveryForceUpdate: false,

  appName: "Fresh Food",
  shortName: "Fresh Food",
  tagline: "Fresh Food at Your Fingertips",
  logoUrl: "",

  primaryColor: "#159447",
  secondaryColor: "#FF6B00",
  accentColor: "#F5B400",

  currencySymbol: "₹",
  supportPhone: "",
  deliveryPromiseText: "20-Min Delivery",
  content: defaultContent,
  payments: {
    merchantCommission: { type: "PERCENTAGE", value: 10 },
    riderEarning: { baseAmount: 30, perKmAmount: 5, minimumAmount: 30 },
    settlement: { merchantEnabled: false, riderPayoutEnabled: false, riderPayoutFrequency: "WEEKLY" },
  },

  home: {
    enabledModules: ["food", "grocery"],
    sections: [
      { id: "modules", enabled: true, sortOrder: 1 },
      { id: "promo", enabled: true, sortOrder: 2 },
      { id: "categories", enabled: true, sortOrder: 3 },
      { id: "nearby", enabled: true, sortOrder: 4 },
    ],
    promoBanners: [
      {
        enabled: true,
        title: "Fresh deals for you",
        subtitle: "Order your favourites today",
        imageUrl: "",
        actionType: "NONE",
        actionValue: "",
      },
      {
        enabled: true,
        title: "Groceries delivered fast",
        subtitle: "Daily essentials at your doorstep",
        imageUrl: "",
        actionType: "MODULE",
        actionValue: "grocery",
      },
    ],
  },
};

export default function SettingsPage() {
  const [settings, setSettings] =
    useState<Settings>(defaultSettings);

  const [loading, setLoading] =
    useState(true);

  const [saving, setSaving] =
    useState(false);

  const [error, setError] =
    useState("");

  const [message, setMessage] =
    useState("");

  const [uploadingImage, setUploadingImage] =
    useState<string | null>(null);

  const [uploadedImageNotice, setUploadedImageNotice] =
    useState<string | null>(null);

  const loadSettings = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response =
        await api.get<Settings>(
          "/admin/settings",
        );

      setSettings({
        ...defaultSettings,
        ...response.data,
        home: {
          ...defaultSettings.home,
          ...(response.data.home ?? {}),
          promoBanners:
            response.data.home?.promoBanners?.length
              ? response.data.home.promoBanners
              : response.data.home?.promoBanner
                ? [
                    {
                      ...defaultSettings.home.promoBanners[0],
                      ...response.data.home.promoBanner,
                    },
                    defaultSettings.home.promoBanners[1],
                  ]
                : defaultSettings.home.promoBanners,
          sections:
            response.data.home?.sections ??
            defaultSettings.home.sections,
          enabledModules:
            response.data.home?.enabledModules ??
            defaultSettings.home.enabledModules,
        },
        content: {
          ...defaultContent,
          ...(response.data.content ?? {}),
          terms: { ...defaultContent.terms, ...(response.data.content?.terms ?? {}) },
          privacy: { ...defaultContent.privacy, ...(response.data.content?.privacy ?? {}) },
          refundPolicy: { ...defaultContent.refundPolicy, ...(response.data.content?.refundPolicy ?? {}) },
          deliveryPolicy: { ...defaultContent.deliveryPolicy, ...(response.data.content?.deliveryPolicy ?? {}) },
          about: { ...defaultContent.about, ...(response.data.content?.about ?? {}) },
          support: { ...defaultContent.support, ...(response.data.content?.support ?? {}) },
          permissions: { ...defaultContent.permissions, ...(response.data.content?.permissions ?? {}) },
        },
        payments: {
          ...defaultSettings.payments,
          ...(response.data.payments ?? {}),
          merchantCommission: { ...defaultSettings.payments.merchantCommission, ...(response.data.payments?.merchantCommission ?? {}) },
          riderEarning: { ...defaultSettings.payments.riderEarning, ...(response.data.payments?.riderEarning ?? {}) },
          settlement: { ...defaultSettings.payments.settlement, ...(response.data.payments?.settlement ?? {}) },
        },
      });
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to load settings.",
        );
      } else {
        setError(
          "Unable to load settings.",
        );
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadSettings();
  }, [loadSettings]);

  const updateField = <K extends keyof Settings>(
    field: K,
    value: Settings[K],
  ) => {
    setSettings((current) => ({
      ...current,
      [field]: value,
    }));
  };

  const uploadImage = async (
    file: File,
    type: "logo" | "promo-banner",
  ) => {
    const formData = new FormData();
    formData.append("file", file);

    const response = await api.post<{
      success: boolean;
      imageUrl: string;
    }>(`/admin/settings/image?type=${type}`, formData);

    return response.data.imageUrl;
  };

  const toggleModule = (
    moduleId: "food" | "grocery",
  ) => {
    setSettings((current) => {
      const enabled =
        current.home.enabledModules.includes(moduleId);

      return {
        ...current,
        home: {
          ...current.home,
          enabledModules: enabled
            ? current.home.enabledModules.filter(
                (item) => item !== moduleId,
              )
            : [
                ...current.home.enabledModules,
                moduleId,
              ],
        },
      };
    });
  };

  const updateHomeSection = (
    sectionId:
      | "modules"
      | "promo"
      | "categories"
      | "nearby",
    field: "enabled" | "sortOrder",
    value: boolean | number,
  ) => {
    setSettings((current) => ({
      ...current,
      home: {
        ...current.home,
        sections: current.home.sections.map(
          (section) =>
            section.id === sectionId
              ? {
                  ...section,
                  [field]: value,
                }
              : section,
        ),
      },
    }));
  };

  const updatePromoField = <K extends keyof PromoBanner>(
    index: number,
    field: K,
    value: PromoBanner[K],
  ) => {
    setSettings((current) => ({
      ...current,
      home: {
        ...current.home,
        promoBanners: current.home.promoBanners.map((banner, bannerIndex) =>
          bannerIndex === index
            ? { ...banner, [field]: value }
            : banner,
        ),
      },
    }));
  };

  const addPromoBanner = () => {
    setSettings((current) => ({
      ...current,
      home: {
        ...current.home,
        promoBanners: [
          ...current.home.promoBanners,
          {
            enabled: true,
            title: "New banner",
            subtitle: "",
            imageUrl: "",
            actionType: "NONE",
            actionValue: "",
          },
        ],
      },
    }));
  };

  const removePromoBanner = (index: number) => {
    setSettings((current) => ({
      ...current,
      home: {
        ...current.home,
        promoBanners: current.home.promoBanners.filter(
          (_, bannerIndex) => bannerIndex !== index,
        ),
      },
    }));
  };

  const updateContent = (section: keyof ContentSettings, field: string, value: string | boolean) => setSettings((current) => ({ ...current, content: { ...current.content, [section]: { ...current.content[section], [field]: value } } }));

  const handleSubmit = async (
    event: FormEvent,
  ) => {
    event.preventDefault();

    try {
      setSaving(true);
      setError("");
      setMessage("");

      const payload = {
        deliveryFee:
          Number(settings.deliveryFee),

        minimumOrder:
          Number(settings.minimumOrder),

        maintenanceMode:
          settings.maintenanceMode,

        customerMinVersion:
          settings.customerMinVersion.trim(),

        customerForceUpdate:
          settings.customerForceUpdate,

        merchantMinVersion:
          settings.merchantMinVersion.trim(),

        merchantForceUpdate:
          settings.merchantForceUpdate,

        deliveryMinVersion:
          settings.deliveryMinVersion.trim(),

        deliveryForceUpdate:
          settings.deliveryForceUpdate,

        appName: settings.appName.trim(),
        shortName: settings.shortName.trim(),
        tagline: settings.tagline.trim(),
        logoUrl: settings.logoUrl.trim(),

        primaryColor: settings.primaryColor.trim(),
        secondaryColor:
          settings.secondaryColor.trim(),
        accentColor: settings.accentColor.trim(),

        currencySymbol:
          settings.currencySymbol.trim(),
        supportPhone: settings.supportPhone.trim(),
        deliveryPromiseText:
          settings.deliveryPromiseText.trim(),

        home: {
          enabledModules: settings.home.enabledModules,
          sections: settings.home.sections,
          promoBanners: settings.home.promoBanners.map((banner) => ({
            enabled: banner.enabled,
            title: banner.title.trim(),
            subtitle: banner.subtitle.trim(),
            imageUrl: banner.imageUrl.trim(),
            actionType: banner.actionType,
            actionValue: banner.actionValue.trim(),
          })),
        },
        content: settings.content,
        payments: settings.payments,
      };

      await api.patch(
        "/admin/settings",
        payload,
      );

      setMessage(
        "Settings updated successfully.",
      );

      await loadSettings();
    } catch (error) {
      if (axios.isAxiosError(error)) {
        setError(
          error.response?.data?.message ??
            "Unable to update settings.",
        );
      } else {
        setError(
          "Unable to update settings.",
        );
      }
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <main className="p-8">
        <p className="text-gray-500">
          Loading settings...
        </p>
      </main>
    );
  }

  return (
    <main className="p-8">
      <div className="mx-auto max-w-5xl">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Settings
          </h1>

          <p className="mt-2 text-gray-500">
            Manage global platform configuration
          </p>
        </div>

        {error && (
          <div className="mt-6 rounded-lg bg-red-50 p-4 text-sm text-red-700">
            {error}
          </div>
        )}

        {message && (
          <div className="mt-6 rounded-lg bg-green-50 p-4 text-sm text-green-700">
            {message}
          </div>
        )}

        <form
          onSubmit={handleSubmit}
          className="mt-8 space-y-6"
        >
          <section className="rounded-xl bg-white p-6 shadow-sm">
            <div className="flex items-start justify-between gap-6">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">
                  Branding
                </h2>

                <p className="mt-1 text-sm text-gray-500">
                  Configure the brand displayed across
                  customer-facing applications.
                </p>
              </div>

              <div
                className="flex h-14 w-14 items-center justify-center overflow-hidden rounded-xl text-xl font-bold text-white"
                style={{
                  backgroundColor:
                    settings.primaryColor ||
                    "#159447",
                }}
              >
                {settings.logoUrl ? (
                  <img
                    src={settings.logoUrl}
                    alt={settings.appName}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  settings.shortName
                    .trim()
                    .charAt(0)
                    .toUpperCase() || "F"
                )}
              </div>
            </div>

            <div className="mt-6 grid gap-5 md:grid-cols-2">
              <TextField
                label="App Name"
                value={settings.appName}
                placeholder="Fresh Food"
                onChange={(value) =>
                  updateField("appName", value)
                }
              />

              <TextField
                label="Short Name"
                value={settings.shortName}
                placeholder="Fresh Food"
                onChange={(value) =>
                  updateField("shortName", value)
                }
              />

              <TextField
                label="Tagline"
                value={settings.tagline}
                placeholder="Fresh Food at Your Fingertips"
                onChange={(value) =>
                  updateField("tagline", value)
                }
              />

              <div>
                <span className="text-sm font-medium text-gray-700">
                  App Logo
                </span>

                <div className="mt-2 flex items-center gap-4">
                  {settings.logoUrl && (
                    <img
                      src={settings.logoUrl}
                      alt="Logo preview"
                      className="h-20 w-20 rounded-xl border object-cover"
                    />
                  )}

                  <label className="cursor-pointer rounded-lg bg-gray-900 px-4 py-3 text-sm font-medium text-white">
                    {uploadingImage === "logo"
                      ? "Uploading..."
                      : "Upload Logo"}
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp"
                      className="hidden"
                      disabled={uploadingImage !== null}
                      onChange={async (event) => {
                        const file = event.target.files?.[0];
                        if (!file) return;

                        const validationError = validateImageFile(file);
                        if (validationError) {
                          setError(validationError);
                          event.target.value = "";
                          return;
                        }

                        try {
                          setUploadingImage("logo");
                          const imageUrl = await uploadImage(file, "logo");
                          updateField("logoUrl", imageUrl);
                          setUploadedImageNotice("logo");
                        } catch (error) {
                          setError(
                            axios.isAxiosError(error)
                              ? error.response?.data?.message ??
                                "Unable to upload logo."
                              : "Unable to upload logo.",
                          );
                        } finally {
                          setUploadingImage(null);
                          event.target.value = "";
                        }
                      }}
                    />
                  </label>
                </div>
                {uploadedImageNotice === "logo" && (
                  <p className="mt-2 text-xs text-gray-500">
                    Image uploaded. Click Save Settings to publish this change.
                  </p>
                )}
              </div>

              <ColorField
                label="Primary Color"
                value={settings.primaryColor}
                onChange={(value) =>
                  updateField("primaryColor", value)
                }
              />

              <ColorField
                label="Secondary Color"
                value={settings.secondaryColor}
                onChange={(value) =>
                  updateField(
                    "secondaryColor",
                    value,
                  )
                }
              />

              <ColorField
                label="Accent Color"
                value={settings.accentColor}
                onChange={(value) =>
                  updateField("accentColor", value)
                }
              />

              <TextField
                label="Currency Symbol"
                value={settings.currencySymbol}
                placeholder="₹"
                onChange={(value) =>
                  updateField(
                    "currencySymbol",
                    value,
                  )
                }
              />

              <TextField
                label="Support Phone"
                value={settings.supportPhone}
                placeholder="+91..."
                onChange={(value) =>
                  updateField("supportPhone", value)
                }
              />

              <TextField
                label="Delivery Promise"
                value={settings.deliveryPromiseText}
                placeholder="20-Min Delivery"
                onChange={(value) =>
                  updateField(
                    "deliveryPromiseText",
                    value,
                  )
                }
              />
            </div>

            <div className="mt-6 rounded-xl border border-gray-200 p-5">
              <p className="text-xs font-medium uppercase tracking-wide text-gray-500">
                Preview
              </p>

              <div className="mt-4 flex items-center gap-4">
                <div
                  className="flex h-14 w-14 items-center justify-center overflow-hidden rounded-xl text-xl font-bold text-white"
                  style={{
                    backgroundColor:
                      settings.primaryColor ||
                      "#159447",
                  }}
                >
                  {settings.logoUrl ? (
                    <img
                      src={settings.logoUrl}
                      alt=""
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    settings.shortName
                      .trim()
                      .charAt(0)
                      .toUpperCase() || "F"
                  )}
                </div>

                <div>
                  <p className="text-lg font-bold text-gray-900">
                    {settings.appName ||
                      "Fresh Food"}
                  </p>

                  <p className="text-sm text-gray-500">
                    {settings.tagline ||
                      "Fresh Food at Your Fingertips"}
                  </p>
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                {[
                  settings.primaryColor,
                  settings.secondaryColor,
                  settings.accentColor,
                ].map((color, index) => (
                  <div
                    key={index}
                    className="h-8 flex-1 rounded-lg border border-black/5"
                    style={{
                      backgroundColor: color,
                    }}
                  />
                ))}
              </div>
            </div>
          </section>

          <section className="space-y-6 rounded-xl bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold">Legal & Customer Content</h2>
            <LegalEditor title="Terms & Conditions" value={settings.content.terms} onChange={(field, value) => updateContent("terms", field, value)} />
            <LegalEditor title="Privacy Policy" value={settings.content.privacy} onChange={(field, value) => updateContent("privacy", field, value)} />
            <LegalEditor title="Refund & Cancellation Policy" value={settings.content.refundPolicy} onChange={(field, value) => updateContent("refundPolicy", field, value)} />
            <LegalEditor title="Delivery Policy" value={settings.content.deliveryPolicy} onChange={(field, value) => updateContent("deliveryPolicy", field, value)} />
            <div className="space-y-4 rounded-xl border p-5"><h3 className="text-lg font-semibold">About Us</h3><TextField label="Title" value={settings.content.about.title} onChange={(value) => updateContent("about", "title", value)} /><textarea className="min-h-[180px] w-full rounded-lg border px-3 py-2" value={settings.content.about.content} onChange={(event) => updateContent("about", "content", event.target.value)} /></div>
            <div className="space-y-4 rounded-xl border p-5"><h3 className="text-lg font-semibold">Support</h3>{([['phone', 'Support phone'], ['email', 'Support email'], ['whatsapp', 'WhatsApp'], ['workingHours', 'Working hours']] as const).map(([field, label]) => <TextField key={field} label={label} value={settings.content.support[field]} onChange={(value) => updateContent("support", field, value)} />)}<textarea className="min-h-[140px] w-full rounded-lg border px-3 py-2" value={settings.content.support.content} placeholder="Support instructions" onChange={(event) => updateContent("support", "content", event.target.value)} /></div>
          </section>

          <section className="rounded-xl bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900">
              Order Configuration
            </h2>

            <p className="mt-1 text-sm text-gray-500">
              Backend-controlled pricing and
              platform order defaults.
            </p>

            <div className="mt-6 grid gap-5 md:grid-cols-2">
              <NumberField
                label="Delivery Fee"
                prefix="₹"
                value={settings.deliveryFee}
                onChange={(value) =>
                  updateField(
                    "deliveryFee",
                    value,
                  )
                }
              />

              <NumberField
                label="Default Minimum Order"
                prefix="₹"
                value={settings.minimumOrder}
                onChange={(value) =>
                  updateField(
                    "minimumOrder",
                    value,
                  )
                }
              />
            </div>

            <p className="mt-4 text-xs text-gray-500">
              Store-specific minimum order values
              currently take precedence during
              checkout.
            </p>
          </section>

          <section className="rounded-xl bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900">
              Platform
            </h2>

            <div className="mt-5">
              <ToggleField
                label="Maintenance Mode"
                description="Temporarily mark the platform as under maintenance."
                checked={
                  settings.maintenanceMode
                }
                onChange={(value) =>
                  updateField(
                    "maintenanceMode",
                    value,
                  )
                }
              />
            </div>
          </section>

          <AppSettingsCard
            title="Customer App"
            version={
              settings.customerMinVersion
            }
            forceUpdate={
              settings.customerForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "customerMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "customerForceUpdate",
                value,
              )
            }
          />

          <AppSettingsCard
            title="Merchant App"
            version={
              settings.merchantMinVersion
            }
            forceUpdate={
              settings.merchantForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "merchantMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "merchantForceUpdate",
                value,
              )
            }
          />

          <AppSettingsCard
            title="Delivery App"
            version={
              settings.deliveryMinVersion
            }
            forceUpdate={
              settings.deliveryForceUpdate
            }
            onVersionChange={(value) =>
              updateField(
                "deliveryMinVersion",
                value,
              )
            }
            onForceUpdateChange={(value) =>
              updateField(
                "deliveryForceUpdate",
                value,
              )
            }
          />

          <section className="rounded-xl border border-gray-200 bg-white p-6">
            <h2 className="text-xl font-semibold">
              Home Configuration
            </h2>

            <p className="mt-1 text-sm text-gray-500">
              Control what customers see on the home screen.
            </p>

            <div className="mt-6">
              <h3 className="font-medium">Enabled Modules</h3>

              <div className="mt-3 flex gap-6">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={settings.home.enabledModules.includes("food")}
                    onChange={() => toggleModule("food")}
                  />
                  Food
                </label>

                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={settings.home.enabledModules.includes("grocery")}
                    onChange={() => toggleModule("grocery")}
                  />
                  Grocery
                </label>
              </div>
            </div>

            <div className="mt-8">
              <h3 className="font-medium">Home Sections</h3>

              <div className="mt-4 space-y-3">
                {settings.home.sections.map((section) => (
                  <div
                    key={section.id}
                    className="flex items-center justify-between rounded-lg border p-4"
                  >
                    <div>
                      <p className="font-medium capitalize">{section.id}</p>
                      <p className="text-sm text-gray-500">
                        Show this section on customer home.
                      </p>
                    </div>

                    <div className="flex items-center gap-4">
                      <input
                        type="number"
                        min={1}
                        className="w-20 rounded-md border px-3 py-2"
                        value={section.sortOrder}
                        onChange={(event) =>
                          updateHomeSection(
                            section.id,
                            "sortOrder",
                            Number(event.target.value),
                          )
                        }
                      />

                      <input
                        type="checkbox"
                        checked={section.enabled}
                        onChange={(event) =>
                          updateHomeSection(
                            section.id,
                            "enabled",
                            event.target.checked,
                          )
                        }
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-8">
              <div className="flex items-center justify-between">
                <h3 className="font-medium">Promo Banners</h3>
                <button
                  type="button"
                  className="rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  onClick={addPromoBanner}
                >
                  Add banner
                </button>
              </div>

              <div className="mt-4 space-y-6">
                {settings.home.promoBanners.map((banner, index) => (
                  <div
                    key={index}
                    className="rounded-xl border border-gray-200 p-4"
                  >
                    <div className="mb-4 flex items-center justify-between">
                      <h4 className="font-medium">Banner {index + 1}</h4>
                      {settings.home.promoBanners.length > 1 && (
                        <button
                          type="button"
                          className="text-sm text-red-600"
                          onClick={() => removePromoBanner(index)}
                        >
                          Remove
                        </button>
                      )}
                    </div>

                    <div className="grid gap-4 md:grid-cols-2">
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={banner.enabled}
                          onChange={(event) =>
                            updatePromoField(
                              index,
                              "enabled",
                              event.target.checked,
                            )
                          }
                        />
                        Enabled
                      </label>

                      <div />

                      <TextField
                        label="Title"
                        value={banner.title}
                        onChange={(value) =>
                          updatePromoField(index, "title", value)
                        }
                      />

                      <TextField
                        label="Subtitle"
                        value={banner.subtitle}
                        onChange={(value) =>
                          updatePromoField(index, "subtitle", value)
                        }
                      />

                      <BannerUpload
                        index={index}
                        banner={banner}
                        uploadingImage={uploadingImage}
                        uploadedImageNotice={uploadedImageNotice}
                        setUploadedImageNotice={setUploadedImageNotice}
                        setUploadingImage={setUploadingImage}
                        uploadImage={uploadImage}
                        onImageUrl={(value) =>
                          updatePromoField(index, "imageUrl", value)
                        }
                        onError={setError}
                      />

                      <label>
                        <span className="text-sm font-medium text-gray-700">
                          Action
                        </span>
                        <select
                          className="mt-2 w-full rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
                          value={banner.actionType}
                          onChange={(event) =>
                            updatePromoField(
                              index,
                              "actionType",
                              event.target.value as
                                | "NONE"
                                | "MODULE"
                                | "CATEGORY",
                            )
                          }
                        >
                          <option value="NONE">None</option>
                          <option value="MODULE">Module</option>
                          <option value="CATEGORY">Category</option>
                        </select>
                      </label>

                      {banner.actionType !== "NONE" && (
                        <div className="md:col-span-2">
                          <TextField
                            label="Action Value"
                            value={banner.actionValue}
                            placeholder={
                              banner.actionType === "MODULE"
                                ? "food or grocery"
                                : "food:Biryani or grocery:Vegetables"
                            }
                            onChange={(value) =>
                              updatePromoField(index, "actionValue", value)
                            }
                          />
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {settings.updatedAt && (
            <p className="text-sm text-gray-500">
              Last updated:{" "}
              {formatDate(
                settings.updatedAt,
              )}
            </p>
          )}

          <div className="flex justify-end">
            <section className="space-y-5 rounded-xl bg-white p-6 shadow-sm">
              <h2 className="text-xl font-bold">Payments & Settlements</h2>
              <label className="block"><span className="text-sm font-medium">Merchant Commission Type</span><select className="mt-1 w-full rounded-lg border px-3 py-2" value={settings.payments.merchantCommission.type} onChange={(event) => setSettings((current) => ({ ...current, payments: { ...current.payments, merchantCommission: { ...current.payments.merchantCommission, type: event.target.value as "PERCENTAGE" | "FIXED" } } }))}><option value="PERCENTAGE">Percentage</option><option value="FIXED">Fixed</option></select></label>
              <NumberField label="Merchant Commission" value={settings.payments.merchantCommission.value} onChange={(value) => setSettings((current) => ({ ...current, payments: { ...current.payments, merchantCommission: { ...current.payments.merchantCommission, value } } }))} />
              <NumberField label="Rider Base Earning" value={settings.payments.riderEarning.baseAmount} onChange={(value) => setSettings((current) => ({ ...current, payments: { ...current.payments, riderEarning: { ...current.payments.riderEarning, baseAmount: value } } }))} />
              <NumberField label="Rider Per KM" value={settings.payments.riderEarning.perKmAmount} onChange={(value) => setSettings((current) => ({ ...current, payments: { ...current.payments, riderEarning: { ...current.payments.riderEarning, perKmAmount: value } } }))} />
              <NumberField label="Minimum Rider Earning" value={settings.payments.riderEarning.minimumAmount} onChange={(value) => setSettings((current) => ({ ...current, payments: { ...current.payments, riderEarning: { ...current.payments.riderEarning, minimumAmount: value } } }))} />
              <label className="flex items-center gap-2"><input type="checkbox" checked={settings.payments.settlement.merchantEnabled} onChange={(event) => setSettings((current) => ({ ...current, payments: { ...current.payments, settlement: { ...current.payments.settlement, merchantEnabled: event.target.checked } } }))} />Enable Merchant Settlements</label>
              <label className="flex items-center gap-2"><input type="checkbox" checked={settings.payments.settlement.riderPayoutEnabled} onChange={(event) => setSettings((current) => ({ ...current, payments: { ...current.payments, settlement: { ...current.payments.settlement, riderPayoutEnabled: event.target.checked } } }))} />Enable Rider Payouts</label>
            </section>

            <button
              type="submit"
              disabled={saving}
              className="rounded-lg bg-gray-900 px-6 py-3 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
            >
              {saving
                ? "Saving..."
                : "Save Settings"}
            </button>
          </div>
        </form>
      </div>
    </main>
  );
}

function validateImageFile(file: File): string | null {
  if (file.size > 5 * 1024 * 1024) {
    return "Image must be 5 MB or smaller.";
  }

  const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
  if (!allowedTypes.includes(file.type)) {
    return "Only JPG, PNG and WEBP images are allowed.";
  }

  return null;
}

function BannerUpload({
  index,
  banner,
  uploadingImage,
  uploadedImageNotice,
  setUploadedImageNotice,
  setUploadingImage,
  uploadImage,
  onImageUrl,
  onError,
}: {
  index: number;
  banner: PromoBanner;
  uploadingImage: string | null;
  uploadedImageNotice: string | null;
  setUploadedImageNotice: (value: string | null) => void;
  setUploadingImage: (value: string | null) => void;
  uploadImage: (
    file: File,
    type: "logo" | "promo-banner",
  ) => Promise<string>;
  onImageUrl: (value: string) => void;
  onError: (value: string) => void;
}) {
  const uploadKey = `banner-${index}`;

  return (
    <div className="md:col-span-2">
      <p className="text-sm font-medium text-gray-700">Banner Image</p>

      {banner.imageUrl && (
        <img
          src={banner.imageUrl}
          alt=""
          className="mt-2 h-40 w-full rounded-xl border object-cover"
        />
      )}

      {uploadedImageNotice === uploadKey && (
        <p className="mt-2 text-xs text-gray-500">
          Image uploaded. Click Save Settings to publish this change.
        </p>
      )}

      <label className="mt-3 inline-block cursor-pointer rounded-lg bg-gray-900 px-4 py-2 text-sm text-white">
        {uploadingImage === uploadKey ? "Uploading..." : "Upload Banner"}
        <input
          type="file"
          accept="image/png,image/jpeg,image/webp"
          className="hidden"
          disabled={uploadingImage !== null}
          onChange={async (event) => {
            const file = event.target.files?.[0];
            if (!file) return;

            const validationError = validateImageFile(file);
            if (validationError) {
              onError(validationError);
              event.target.value = "";
              return;
            }

            try {
              setUploadingImage(uploadKey);
              const imageUrl = await uploadImage(file, "promo-banner");
              onImageUrl(imageUrl);
              setUploadedImageNotice(uploadKey);
            } catch (error) {
              onError(
                axios.isAxiosError(error)
                  ? error.response?.data?.message ??
                    "Unable to upload banner."
                  : "Unable to upload banner.",
              );
            } finally {
              setUploadingImage(null);
              event.target.value = "";
            }
          }}
        />
      </label>
    </div>
  );
}

function LegalEditor({ title, value, onChange }: { title: string; value: LegalContent; onChange: (field: keyof LegalContent, value: string | boolean) => void }) {
  return <div className="space-y-4 rounded-xl border p-5"><div className="flex items-center justify-between"><h3 className="text-lg font-semibold">{title}</h3><label className="flex items-center gap-2"><input type="checkbox" checked={value.isEnabled} onChange={(event) => onChange("isEnabled", event.target.checked)} /> Enabled</label></div><TextField label="Title" value={value.title} onChange={(next) => onChange("title", next)} /><TextField label="Version" value={value.version} onChange={(next) => onChange("version", next)} /><textarea className="min-h-[260px] w-full rounded-lg border px-3 py-2" value={value.content} placeholder="Enter policy content..." onChange={(event) => onChange("content", event.target.value)} /></div>;
}

function TextField({
  label,
  value,
  placeholder,
  onChange,
}: {
  label: string;
  value: string;
  placeholder?: string;
  onChange: (value: string) => void;
}) {
  return (
    <label>
      <span className="text-sm font-medium text-gray-700">
        {label}
      </span>

      <input
        type="text"
        value={value}
        placeholder={placeholder}
        onChange={(event) =>
          onChange(event.target.value)
        }
        className="mt-2 w-full rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
      />
    </label>
  );
}

function ColorField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label>
      <span className="text-sm font-medium text-gray-700">
        {label}
      </span>

      <div className="mt-2 flex overflow-hidden rounded-lg border border-gray-300">
        <input
          type="color"
          value={value}
          onChange={(event) =>
            onChange(
              event.target.value.toUpperCase(),
            )
          }
          className="h-12 w-14 cursor-pointer border-0 bg-transparent p-1"
        />

        <input
          type="text"
          value={value}
          onChange={(event) =>
            onChange(event.target.value)
          }
          placeholder="#159447"
          maxLength={7}
          className="min-w-0 flex-1 px-4 outline-none"
        />
      </div>
    </label>
  );
}

function NumberField({
  label,
  prefix,
  value,
  onChange,
}: {
  label: string;
  prefix?: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label>
      <span className="text-sm font-medium text-gray-700">
        {label}
      </span>

      <div className="mt-2 flex rounded-lg border border-gray-300">
        {prefix && (
          <span className="flex items-center border-r border-gray-300 px-4 text-gray-500">
            {prefix}
          </span>
        )}

        <input
          type="number"
          min="0"
          step="0.01"
          value={value}
          onChange={(event) =>
            onChange(
              Number(event.target.value),
            )
          }
          className="w-full rounded-r-lg px-4 py-3 outline-none"
        />
      </div>
    </label>
  );
}

function ToggleField({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-6">
      <div>
        <p className="font-medium text-gray-900">
          {label}
        </p>

        <p className="mt-1 text-sm text-gray-500">
          {description}
        </p>
      </div>

      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() =>
          onChange(!checked)
        }
        className={`relative h-7 w-12 rounded-full transition ${
          checked
            ? "bg-green-600"
            : "bg-gray-300"
        }`}
      >
        <span
          className={`absolute top-1 h-5 w-5 rounded-full bg-white transition ${
            checked
              ? "left-6"
              : "left-1"
          }`}
        />
      </button>
    </div>
  );
}

function AppSettingsCard({
  title,
  version,
  forceUpdate,
  onVersionChange,
  onForceUpdateChange,
}: {
  title: string;
  version: string;
  forceUpdate: boolean;
  onVersionChange: (
    value: string,
  ) => void;
  onForceUpdateChange: (
    value: boolean,
  ) => void;
}) {
  return (
    <section className="rounded-xl bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">
        {title}
      </h2>

      <div className="mt-6 grid gap-6 md:grid-cols-2">
        <label>
          <span className="text-sm font-medium text-gray-700">
            Minimum Version
          </span>

          <input
            value={version}
            onChange={(event) =>
              onVersionChange(
                event.target.value,
              )
            }
            placeholder="1.0.0"
            className="mt-2 w-full rounded-lg border border-gray-300 px-4 py-3 outline-none focus:border-gray-500"
          />
        </label>

        <ToggleField
          label="Force Update"
          description="Require users below the minimum version to update."
          checked={forceUpdate}
          onChange={
            onForceUpdateChange
          }
        />
      </div>
    </section>
  );
}

function formatDate(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}
