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
