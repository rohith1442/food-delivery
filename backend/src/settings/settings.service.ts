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
        };
    }
  }
}