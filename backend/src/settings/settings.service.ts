import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

type AppType =
  | 'CUSTOMER'
  | 'MERCHANT'
  | 'DELIVERY';

interface GlobalSettings {
  maintenanceMode?: boolean;

  customerMinVersion?: string;
  customerForceUpdate?: boolean;

  merchantMinVersion?: string;
  merchantForceUpdate?: boolean;

  deliveryMinVersion?: string;
  deliveryForceUpdate?: boolean;

  appName?: string;
  shortName?: string;
  tagline?: string;
  logoUrl?: string;

  primaryColor?: string;
  secondaryColor?: string;
  accentColor?: string;

  currencySymbol?: string;
  supportPhone?: string;
  deliveryPromiseText?: string;
  content?: Record<string, any>;

  home?: {
    enabledModules?: string[];
    sections?: Array<{
      id: string;
      enabled: boolean;
      sortOrder: number;
    }>;
    promoBanner?: {
      enabled?: boolean;
      title?: string;
      subtitle?: string;
      imageUrl?: string;
      actionType?: 'NONE' | 'MODULE' | 'CATEGORY';
      actionValue?: string;
    };
  };
}

@Injectable()
export class SettingsService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  private getDefaultContent() {
    return {
      terms: { title: 'Terms & Conditions', content: '', version: '1.0', isEnabled: true },
      privacy: { title: 'Privacy Policy', content: '', version: '1.0', isEnabled: true },
      refundPolicy: { title: 'Refund & Cancellation Policy', content: '', version: '1.0', isEnabled: true },
      deliveryPolicy: { title: 'Delivery Policy', content: '', version: '1.0', isEnabled: true },
      about: { title: 'About Us', content: '', isEnabled: true },
      support: { title: 'Contact Support', content: '', phone: '', email: '', whatsapp: '', workingHours: '', isEnabled: true },
      permissions: { title: 'App Permissions', location: '', notifications: '', camera: '', photos: '', isEnabled: true },
    };
  }

  async getContent() {
    const snapshot = await this.firebaseService.getFirestore().collection('settings').doc('global').get();
    const data = snapshot.exists ? snapshot.data() ?? {} : {};
    const defaults = this.getDefaultContent() as Record<string, any>;
    const current = (data.content ?? {}) as Record<string, any>;
    const content: Record<string, any> = { ...defaults, ...current };
    for (const key of Object.keys(defaults)) content[key] = { ...defaults[key], ...(current[key] ?? {}) };
    return { content };
  }

  async getContentByType(type: string) {
    const aliases: Record<string, string> = { terms: 'terms', privacy: 'privacy', refund: 'refundPolicy', 'refund-policy': 'refundPolicy', refundpolicy: 'refundPolicy', delivery: 'deliveryPolicy', 'delivery-policy': 'deliveryPolicy', deliverypolicy: 'deliveryPolicy', about: 'about', support: 'support', permissions: 'permissions' };
    const key = aliases[type.trim().toLowerCase()];
    return key ? { type: key, content: (await this.getContent()).content[key] } : { content: null };
  }

  async getAppConfig(app: string) {
    const appType =
      app?.trim().toUpperCase() as AppType;

    if (
      ![
        'CUSTOMER',
        'MERCHANT',
        'DELIVERY',
      ].includes(appType)
    ) {
      throw new BadRequestException(
        'app must be CUSTOMER, MERCHANT or DELIVERY',
      );
    }

    const db =
      this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('settings')
      .doc('global')
      .get();

    const settings =
      snapshot.exists
        ? (snapshot.data() as GlobalSettings)
        : {};

    const maintenanceMode =
      settings.maintenanceMode === true;

    const branding = {
      appName: settings.appName ?? 'Fresh Food',
      shortName: settings.shortName ?? 'Fresh Food',
      tagline:
        settings.tagline ??
        'Fresh Food at Your Fingertips',
      logoUrl: settings.logoUrl ?? '',
      primaryColor: settings.primaryColor ?? '#159447',
      secondaryColor:
        settings.secondaryColor ?? '#FF6B00',
      accentColor: settings.accentColor ?? '#F5B400',
      currencySymbol: settings.currencySymbol ?? '₹',
      supportPhone: settings.supportPhone ?? '',
      deliveryPromiseText:
        settings.deliveryPromiseText ??
        '20-Min Delivery',
    };

    const home = {
      enabledModules:
        settings.home?.enabledModules ?? [
          'food',
          'grocery',
        ],
      sections:
        settings.home?.sections ?? [
          {
            id: 'modules',
            enabled: true,
            sortOrder: 1,
          },
          {
            id: 'promo',
            enabled: true,
            sortOrder: 2,
          },
          {
            id: 'categories',
            enabled: true,
            sortOrder: 3,
          },
          {
            id: 'nearby',
            enabled: true,
            sortOrder: 4,
          },
        ],
      promoBanner: {
        enabled:
          settings.home?.promoBanner?.enabled ??
          true,
        title:
          settings.home?.promoBanner?.title ??
          'Fresh deals for you',
        subtitle:
          settings.home?.promoBanner?.subtitle ??
          'Order your favourites today',
        imageUrl:
          settings.home?.promoBanner?.imageUrl ??
          '',
        actionType:
          settings.home?.promoBanner?.actionType ??
          'NONE',
        actionValue:
          settings.home?.promoBanner?.actionValue ??
          '',
      },
    };

    switch (appType) {
      case 'CUSTOMER':
        return {
          app: appType,
          maintenanceMode,
          minimumVersion:
            settings.customerMinVersion ??
            '1.0.0',
          forceUpdate:
            settings.customerForceUpdate ===
            true,
          branding,
          home,
        };

      case 'MERCHANT':
        return {
          app: appType,
          maintenanceMode,
          minimumVersion:
            settings.merchantMinVersion ??
            '1.0.0',
          forceUpdate:
            settings.merchantForceUpdate ===
            true,
          branding,
        };

      case 'DELIVERY':
        return {
          app: appType,
          maintenanceMode,
          minimumVersion:
            settings.deliveryMinVersion ??
            '1.0.0',
          forceUpdate:
            settings.deliveryForceUpdate ===
            true,
          branding,
        };
    }
  }
}
