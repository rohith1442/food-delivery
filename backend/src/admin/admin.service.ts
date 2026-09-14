import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { randomUUID } from 'node:crypto';

import { FirebaseService } from '../firebase/firebase.service.js';

interface UserDocument {
  uid?: string;
  email?: string | null;
  phoneNumber?: string | null;
  name?: string | null;
  businessName?: string | null;
  role?: string;
  status?: string;
  isActive?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

interface ModuleDocument {
  name?: string;
  description?: string;
  imageUrl?: string;
  isActive?: boolean;
  sortOrder?: number;
  createdAt?: string;
  updatedAt?: string;
}
interface StoreDocument {
  id?: string;
  merchantId?: string;
  name?: string;
  moduleId?: string;
  zoneId?: string;
  address?: string;
  latitude?: number | null;
  longitude?: number | null;
  minimumOrder?: number;
  isActive?: boolean;
  isOpen?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

interface OrderDocument {
  createdAt?: string;
  updatedAt?: string;
  status?: string;
  customerId?: string;
  storeId?: string;
  total?: number;
  subtotal?: number;
  deliveryFee?: number;
  [key: string]: unknown;
}

interface ZoneDocument {
  name?: string;
  city?: string;
  state?: string;
  centerLatitude?: number;
  centerLongitude?: number;
  radiusKm?: number;
  isActive?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

interface GlobalSettingsDocument {
  deliveryFee?: number;
  minimumOrder?: number;
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
      id:
        | 'modules'
        | 'promo'
        | 'categories'
        | 'nearby';
      enabled: boolean;
      sortOrder: number;
    }>;
    promoBanner?: {
      enabled?: boolean;
      title?: string;
      subtitle?: string;
      imageUrl?: string;
      actionType?:
        | 'NONE'
        | 'MODULE'
        | 'CATEGORY';
      actionValue?: string;
    };
  };

  updatedAt?: string;
}

@Injectable()
export class AdminService {
  constructor(private readonly firebaseService: FirebaseService) {}

  async getUsers(status = 'PENDING') {
    const db = this.firebaseService.getFirestore();

    const normalizedStatus = status.trim().toUpperCase();

    const snapshot = await db
      .collection('users')
      .where('status', '==', normalizedStatus)
      .get();

    return snapshot.docs
      .map((doc) => {
        const data = doc.data() as UserDocument;

        return {
          id: doc.id,
          ...data,
        };
      })
      .filter((user) => {
        const role = user.role?.trim().toUpperCase();

        return role === 'MERCHANT' || role === 'DELIVERY';
      });
  }

  async approveUser(uid: string) {
    const db = this.firebaseService.getFirestore();

    const userRef = db.collection('users').doc(uid);

    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw new NotFoundException('User not found');
      }

      const user = snapshot.data() as UserDocument;

      const role = user.role?.trim().toUpperCase();

      const status = user.status?.trim().toUpperCase();

      if (role !== 'MERCHANT' && role !== 'DELIVERY') {
        throw new BadRequestException(
          'Only merchant or delivery accounts can be approved',
        );
      }

      if (status !== 'PENDING') {
        throw new BadRequestException(
          `User cannot be approved from status ${status ?? 'UNKNOWN'}`,
        );
      }

      const updatedAt = new Date().toISOString();

      transaction.update(userRef, {
        status: 'ACTIVE',
        isActive: true,
        updatedAt,
      });

      return {
        uid,
        role,
        status: 'ACTIVE',
        isActive: true,
        updatedAt,
      };
    });
  }

  async rejectUser(uid: string) {
    const db = this.firebaseService.getFirestore();

    const userRef = db.collection('users').doc(uid);

    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw new NotFoundException('User not found');
      }

      const user = snapshot.data() as UserDocument;

      const role = user.role?.trim().toUpperCase();

      const status = user.status?.trim().toUpperCase();

      if (role !== 'MERCHANT' && role !== 'DELIVERY') {
        throw new BadRequestException(
          'Only merchant or delivery accounts can be rejected',
        );
      }

      if (status !== 'PENDING') {
        throw new BadRequestException(
          `User cannot be rejected from status ${status ?? 'UNKNOWN'}`,
        );
      }

      const updatedAt = new Date().toISOString();

      transaction.update(userRef, {
        status: 'REJECTED',
        isActive: false,
        updatedAt,
      });

      return {
        uid,
        role,
        status: 'REJECTED',
        isActive: false,
        updatedAt,
      };
    });
  }

  async assignDeliveryZone(uid: string, zoneId: string) {
    const normalizedZoneId = zoneId?.trim();

    if (!normalizedZoneId) {
      throw new BadRequestException('zoneId is required');
    }

    const db = this.firebaseService.getFirestore();

    const userRef = db.collection('users').doc(uid);

    const zoneRef = db.collection('zones').doc(normalizedZoneId);

    const deliveryPartnerRef = db.collection('delivery_partners').doc(uid);

    return db.runTransaction(async (transaction) => {
      const [userSnapshot, zoneSnapshot, deliveryPartnerSnapshot] =
        await Promise.all([
          transaction.get(userRef),
          transaction.get(zoneRef),
          transaction.get(deliveryPartnerRef),
        ]);

      if (!userSnapshot.exists) {
        throw new NotFoundException('User not found');
      }

      const user = userSnapshot.data() as UserDocument;

      const role = user.role?.trim().toUpperCase();

      const status = user.status?.trim().toUpperCase();

      if (role !== 'DELIVERY') {
        throw new BadRequestException(
          'Only delivery partners can be assigned a delivery zone',
        );
      }

      if (status !== 'ACTIVE' || user.isActive !== true) {
        throw new BadRequestException(
          'Delivery partner must be active before assigning a zone',
        );
      }

      if (!zoneSnapshot.exists) {
        throw new NotFoundException('Zone not found');
      }

      const zone = zoneSnapshot.data() as ZoneDocument;

      if (zone.isActive !== true) {
        throw new BadRequestException('Cannot assign an inactive zone');
      }

      const now = new Date().toISOString();

      const profile = {
        userId: uid,
        zoneId: normalizedZoneId,
        isOnline: false,
        isAvailable: false,
        updatedAt: now,
      };

      if (deliveryPartnerSnapshot.exists) {
        transaction.update(deliveryPartnerRef, profile);
      } else {
        transaction.set(deliveryPartnerRef, {
          ...profile,
          createdAt: now,
        });
      }

      return {
        success: true,
        profile: {
          ...profile,
          ...(deliveryPartnerSnapshot.exists ? {} : { createdAt: now }),
        },
      };
    });
  }

  async getOrders(status?: string) {
    const db = this.firebaseService.getFirestore();

    let query: FirebaseFirestore.Query = db.collection('orders');

    if (status?.trim()) {
      query = query.where('status', '==', status.trim().toUpperCase());
    }

    const snapshot = await query.get();

    const orders = snapshot.docs.map((doc) => {
      const data = doc.data() as OrderDocument;

      return {
        id: doc.id,
        ...data,
      };
    });

    return orders.sort((a, b) => {
      const aCreatedAt =
        typeof a.createdAt === 'string' ? new Date(a.createdAt).getTime() : 0;

      const bCreatedAt =
        typeof b.createdAt === 'string' ? new Date(b.createdAt).getTime() : 0;

      return bCreatedAt - aCreatedAt;
    });
  }
  async getStores() {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('stores').get();

    const stores = snapshot.docs.map((doc) => {
      const data = doc.data() as StoreDocument;

      return {
        id: doc.id,
        ...data,
      };
    });

    return stores.sort((a, b) => {
      const aCreatedAt =
        typeof a.createdAt === 'string' ? new Date(a.createdAt).getTime() : 0;

      const bCreatedAt =
        typeof b.createdAt === 'string' ? new Date(b.createdAt).getTime() : 0;

      return bCreatedAt - aCreatedAt;
    });
  }

  async updateStoreStatus(storeId: string, isActive: boolean) {
    if (typeof isActive !== 'boolean') {
      throw new BadRequestException('isActive must be a boolean');
    }

    const db = this.firebaseService.getFirestore();

    const storeRef = db.collection('stores').doc(storeId);

    const snapshot = await storeRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Store not found');
    }

    const updatedAt = new Date().toISOString();

    await storeRef.update({
      isActive,
      updatedAt,
    });

    return {
      success: true,
      storeId,
      isActive,
      updatedAt,
    };
  }

  async getAllUsers(role?: string, status?: string) {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('users').get();

    let users = snapshot.docs.map((doc) => {
      const data = doc.data() as UserDocument;

      return {
        id: doc.id,
        ...data,
      };
    });

    if (role?.trim()) {
      const normalizedRole = role.trim().toUpperCase();

      users = users.filter(
        (user) => user.role?.trim().toUpperCase() === normalizedRole,
      );
    }

    if (status?.trim()) {
      const normalizedStatus = status.trim().toUpperCase();

      users = users.filter(
        (user) => user.status?.trim().toUpperCase() === normalizedStatus,
      );
    }

    const usersWithDeliveryProfile = await Promise.all(
      users.map(async (user) => {
        if (user.role?.trim().toUpperCase() !== 'DELIVERY') {
          return user;
        }

        const deliveryPartnerSnapshot = await db
          .collection('delivery_partners')
          .doc(user.id)
          .get();

        if (!deliveryPartnerSnapshot.exists) {
          return {
            ...user,
            zoneId: null,
            isOnline: false,
            isAvailable: false,
          };
        }

        const deliveryPartner = deliveryPartnerSnapshot.data();

        return {
          ...user,
          zoneId:
            typeof deliveryPartner?.zoneId === 'string'
              ? deliveryPartner.zoneId
              : null,
          isOnline: deliveryPartner?.isOnline === true,
          isAvailable: deliveryPartner?.isAvailable === true,
        };
      }),
    );

    return usersWithDeliveryProfile.sort((a, b) => {
      const aCreatedAt =
        typeof a.createdAt === 'string' ? new Date(a.createdAt).getTime() : 0;

      const bCreatedAt =
        typeof b.createdAt === 'string' ? new Date(b.createdAt).getTime() : 0;

      return bCreatedAt - aCreatedAt;
    });
  }

  async updateUserStatus(uid: string, isActive: boolean) {
    if (typeof isActive !== 'boolean') {
      throw new BadRequestException('isActive must be a boolean');
    }

    const db = this.firebaseService.getFirestore();

    const userRef = db.collection('users').doc(uid);

    const snapshot = await userRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('User not found');
    }

    const user = snapshot.data() as UserDocument;

    const role = user.role?.trim().toUpperCase();

    // Never allow this endpoint to disable an ADMIN.
    if (role === 'ADMIN') {
      throw new BadRequestException(
        'Admin accounts cannot be changed using this endpoint',
      );
    }

    const currentStatus = user.status?.trim().toUpperCase();

    if (currentStatus === 'PENDING' || currentStatus === 'REJECTED') {
      throw new BadRequestException(
        `User cannot be ${
          isActive ? 'activated' : 'suspended'
        } from status ${currentStatus}`,
      );
    }

    const status = isActive ? 'ACTIVE' : 'SUSPENDED';

    const updatedAt = new Date().toISOString();

    await userRef.update({
      status,
      isActive,
      updatedAt,
    });

    return {
      success: true,
      uid,
      role,
      status,
      isActive,
      updatedAt,
    };
  }
  async getOrder(orderId: string) {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('orders').doc(orderId).get();

    if (!snapshot.exists) {
      throw new NotFoundException('Order not found');
    }

    return {
      id: snapshot.id,
      ...snapshot.data(),
    };
  }

  async getZones() {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('zones').get();

    const zones = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() as ZoneDocument),
    }));

    return zones.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? ''));
  }

  async createZone(data: {
    name: string;
    city?: string;
    state?: string;
    centerLatitude: number;
    centerLongitude: number;
    radiusKm: number;
  }) {
    const name = data.name?.trim();

    if (!name) {
      throw new BadRequestException('Zone name is required');
    }

    this.validateZoneCoverage(
      data.centerLatitude,
      data.centerLongitude,
      data.radiusKm,
    );

    const db = this.firebaseService.getFirestore();

    const existingSnapshot = await db.collection('zones').get();

    const duplicate = existingSnapshot.docs.some((doc) => {
      const zone = doc.data() as ZoneDocument;

      return zone.name?.trim().toLowerCase() === name.toLowerCase();
    });

    if (duplicate) {
      throw new BadRequestException('Zone already exists');
    }

    const now = new Date().toISOString();

    const zone = {
      name,
      city: data.city?.trim() ?? '',
      state: data.state?.trim() ?? '',
      centerLatitude: data.centerLatitude,
      centerLongitude: data.centerLongitude,
      radiusKm: data.radiusKm,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    const ref = await db.collection('zones').add(zone);

    return {
      id: ref.id,
      ...zone,
    };
  }

  async updateZone(
    zoneId: string,
    data: {
      name?: string;
      city?: string;
      state?: string;
      centerLatitude?: number;
      centerLongitude?: number;
      radiusKm?: number;
    },
  ) {
    const db = this.firebaseService.getFirestore();

    const zoneRef = db.collection('zones').doc(zoneId);

    const snapshot = await zoneRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Zone not found');
    }

    const currentZone = snapshot.data() as ZoneDocument;

    const centerLatitude = data.centerLatitude ?? currentZone.centerLatitude;

    const centerLongitude = data.centerLongitude ?? currentZone.centerLongitude;

    const radiusKm = data.radiusKm ?? currentZone.radiusKm;

    const coverageProvided =
      data.centerLatitude !== undefined ||
      data.centerLongitude !== undefined ||
      data.radiusKm !== undefined;

    if (coverageProvided) {
      if (
        centerLatitude === undefined ||
        centerLongitude === undefined ||
        radiusKm === undefined
      ) {
        throw new BadRequestException(
          'centerLatitude, centerLongitude and radiusKm are required for zone coverage',
        );
      }

      this.validateZoneCoverage(centerLatitude, centerLongitude, radiusKm);
    }

    const updates: Partial<ZoneDocument> = {
      updatedAt: new Date().toISOString(),
    };

    if (data.name !== undefined) {
      const name = data.name.trim();

      if (!name) {
        throw new BadRequestException('Zone name cannot be empty');
      }

      updates.name = name;
    }

    if (data.city !== undefined) {
      updates.city = data.city.trim();
    }

    if (data.state !== undefined) {
      updates.state = data.state.trim();
    }

    if (data.centerLatitude !== undefined) {
      updates.centerLatitude = data.centerLatitude;
    }

    if (data.centerLongitude !== undefined) {
      updates.centerLongitude = data.centerLongitude;
    }

    if (data.radiusKm !== undefined) {
      updates.radiusKm = data.radiusKm;
    }

    await zoneRef.update(updates);

    const updatedSnapshot = await zoneRef.get();

    return {
      id: updatedSnapshot.id,
      ...(updatedSnapshot.data() as ZoneDocument),
    };
  }

  async updateZoneStatus(zoneId: string, isActive: boolean) {
    if (typeof isActive !== 'boolean') {
      throw new BadRequestException('isActive must be a boolean');
    }

    const db = this.firebaseService.getFirestore();

    const zoneRef = db.collection('zones').doc(zoneId);

    const snapshot = await zoneRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Zone not found');
    }

    const updatedAt = new Date().toISOString();

    await zoneRef.update({
      isActive,
      updatedAt,
    });

    return {
      success: true,
      id: zoneId,
      isActive,
      updatedAt,
    };
  }
  async getModules() {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('modules').get();

    const modules = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() as ModuleDocument),
    }));

    return modules.sort((a, b) => {
      const aOrder = a.sortOrder ?? 999;
      const bOrder = b.sortOrder ?? 999;

      if (aOrder !== bOrder) {
        return aOrder - bOrder;
      }

      return (a.name ?? a.id).localeCompare(
        b.name ?? b.id,
      );
    });
  }

  async updateModuleStatus(moduleId: string, isActive: boolean) {
    if (typeof isActive !== 'boolean') {
      throw new BadRequestException('isActive must be a boolean');
    }

    const db = this.firebaseService.getFirestore();

    const moduleRef = db.collection('modules').doc(moduleId);

    const snapshot = await moduleRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Module not found');
    }

    const updatedAt = new Date().toISOString();

    await moduleRef.update({
      isActive,
      updatedAt,
    });

    return {
      success: true,
      id: moduleId,
      isActive,
      updatedAt,
    };
  }

  async updateModuleOrder(
    moduleId: string,
    sortOrder: number,
  ) {
    if (
      typeof sortOrder !== 'number' ||
      !Number.isInteger(sortOrder) ||
      sortOrder < 1
    ) {
      throw new BadRequestException(
        'sortOrder must be an integer greater than 0',
      );
    }

    const db = this.firebaseService.getFirestore();
    const moduleRef = db.collection('modules').doc(moduleId);
    const snapshot = await moduleRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Module not found');
    }

    const updatedAt = new Date().toISOString();

    await moduleRef.update({
      sortOrder,
      updatedAt,
    });

    return {
      success: true,
      id: moduleId,
      sortOrder,
      updatedAt,
    };
  }

  async uploadModuleImage(
    moduleId: string,
    file: Express.Multer.File,
  ) {
    const normalizedModuleId = moduleId?.trim();

    if (!normalizedModuleId) {
      throw new BadRequestException('Module ID is required');
    }

    if (!file) {
      throw new BadRequestException('Image file is required');
    }

    const allowedMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];

    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        'Only JPG, PNG and WEBP images are allowed',
      );
    }

    const db = this.firebaseService.getFirestore();
    const moduleRef = db.collection('modules').doc(normalizedModuleId);
    const moduleSnapshot = await moduleRef.get();

    if (!moduleSnapshot.exists) {
      throw new NotFoundException('Module not found');
    }

    const extension =
      file.mimetype === 'image/png'
        ? 'png'
        : file.mimetype === 'image/webp'
          ? 'webp'
          : 'jpg';

    const fileName =
      `modules/${normalizedModuleId}/${randomUUID()}.${extension}`;
    const bucket = this.firebaseService.getStorage().bucket();
    const storageFile = bucket.file(fileName);
    const downloadToken = randomUUID();

    await storageFile.save(file.buffer, {
      metadata: {
        contentType: file.mimetype,
        metadata: {
          firebaseStorageDownloadTokens: downloadToken,
        },
      },
      resumable: false,
    });

    const encodedPath = encodeURIComponent(fileName);
    const imageUrl =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;
    const updatedAt = new Date().toISOString();

    await moduleRef.update({
      imageUrl,
      updatedAt,
    });

    return {
      success: true,
      moduleId: normalizedModuleId,
      imageUrl,
      updatedAt,
      path: fileName,
    };
  }
  async getDashboard() {
    const db = this.firebaseService.getFirestore();

    const [usersSnapshot, ordersSnapshot, storesSnapshot, zonesSnapshot] =
      await Promise.all([
        db.collection('users').get(),
        db.collection('orders').get(),
        db.collection('stores').get(),
        db.collection('zones').get(),
      ]);

    const users = usersSnapshot.docs.map((doc) => doc.data());

    const orders = ordersSnapshot.docs.map((doc) => doc.data());

    const stores = storesSnapshot.docs.map((doc) => doc.data());

    const zones = zonesSnapshot.docs.map((doc) => doc.data());

    const pendingApprovals = users.filter(
      (user) =>
        user.status?.toUpperCase() === 'PENDING' &&
        (user.role?.toUpperCase() === 'MERCHANT' ||
          user.role?.toUpperCase() === 'DELIVERY'),
    ).length;

    const customers = users.filter(
      (user) => user.role?.toUpperCase() === 'CUSTOMER',
    ).length;

    const activeMerchants = users.filter(
      (user) =>
        user.role?.toUpperCase() === 'MERCHANT' &&
        user.status?.toUpperCase() === 'ACTIVE' &&
        user.isActive === true,
    ).length;

    const activeDeliveryPartners = users.filter(
      (user) =>
        user.role?.toUpperCase() === 'DELIVERY' &&
        user.status?.toUpperCase() === 'ACTIVE' &&
        user.isActive === true,
    ).length;

    const activeStores = stores.filter(
      (store) => store.isActive === true,
    ).length;

    const activeZones = zones.filter((zone) => zone.isActive === true).length;

    const deliveredOrders = orders.filter(
      (order) => order.status?.toUpperCase() === 'DELIVERED',
    );

    const revenue = deliveredOrders.reduce((total, order) => {
      const amount =
        typeof order.total === 'number'
          ? order.total
          : typeof order.totalAmount === 'number'
            ? order.totalAmount
            : 0;

      return total + amount;
    }, 0);

    return {
      pendingApprovals,
      totalOrders: orders.length,
      activeStores,
      customers,
      activeMerchants,
      activeDeliveryPartners,
      activeZones,
      deliveredOrders: deliveredOrders.length,
      revenue,
    };
  }
  async getSettings() {
    const db = this.firebaseService.getFirestore();

    const settingsRef = db.collection('settings').doc('global');

    const snapshot = await settingsRef.get();

    if (!snapshot.exists) {
      return {
        deliveryFee: 40,
        minimumOrder: 0,
        maintenanceMode: false,

        customerMinVersion: '1.0.0',
        customerForceUpdate: false,

        merchantMinVersion: '1.0.0',
        merchantForceUpdate: false,

        deliveryMinVersion: '1.0.0',
        deliveryForceUpdate: false,

        appName: 'Fresh Food',
        shortName: 'Fresh Food',
        tagline: 'Fresh Food at Your Fingertips',
        logoUrl: '',

        primaryColor: '#159447',
        secondaryColor: '#FF6B00',
        accentColor: '#F5B400',

        currencySymbol: '₹',
        supportPhone: '',
        deliveryPromiseText: '20-Min Delivery',
        content: this.getDefaultContent(),
      };
    }

    return snapshot.data();
  }
  async updateSettings(data: Partial<GlobalSettingsDocument>) {
    const db = this.firebaseService.getFirestore();

    const settingsRef = db.collection('settings').doc('global');

    const updates: Partial<GlobalSettingsDocument> = {};

    if (data.deliveryFee !== undefined) {
      if (
        typeof data.deliveryFee !== 'number' ||
        !Number.isFinite(data.deliveryFee) ||
        data.deliveryFee < 0
      ) {
        throw new BadRequestException(
          'deliveryFee must be a valid number greater than or equal to 0',
        );
      }

      updates.deliveryFee = data.deliveryFee;
    }

    if (data.minimumOrder !== undefined) {
      if (
        typeof data.minimumOrder !== 'number' ||
        !Number.isFinite(data.minimumOrder) ||
        data.minimumOrder < 0
      ) {
        throw new BadRequestException(
          'minimumOrder must be a valid number greater than or equal to 0',
        );
      }

      updates.minimumOrder = data.minimumOrder;
    }

    if (data.maintenanceMode !== undefined) {
      if (typeof data.maintenanceMode !== 'boolean') {
        throw new BadRequestException('maintenanceMode must be a boolean');
      }

      updates.maintenanceMode = data.maintenanceMode;
    }

    if (data.customerMinVersion !== undefined) {
      updates.customerMinVersion = this.validateVersion(
        data.customerMinVersion,
        'customerMinVersion',
      );
    }

    if (data.merchantMinVersion !== undefined) {
      updates.merchantMinVersion = this.validateVersion(
        data.merchantMinVersion,
        'merchantMinVersion',
      );
    }

    if (data.deliveryMinVersion !== undefined) {
      updates.deliveryMinVersion = this.validateVersion(
        data.deliveryMinVersion,
        'deliveryMinVersion',
      );
    }

    const booleanFields: Array<keyof GlobalSettingsDocument> = [
      'customerForceUpdate',
      'merchantForceUpdate',
      'deliveryForceUpdate',
    ];

    for (const field of booleanFields) {
      const value = data[field];

      if (value === undefined) {
        continue;
      }

      if (typeof value !== 'boolean') {
        throw new BadRequestException(`${field} must be a boolean`);
      }

      Object.assign(updates, {
        [field]: value,
      });
    }

    const stringFields: Array<
      keyof GlobalSettingsDocument
    > = [
      'appName',
      'shortName',
      'tagline',
      'logoUrl',
      'currencySymbol',
      'supportPhone',
      'deliveryPromiseText',
    ];

    for (const field of stringFields) {
      const value = data[field];

      if (value === undefined) {
        continue;
      }

      if (typeof value !== 'string') {
        throw new BadRequestException(
          `${field} must be a string`,
        );
      }

      Object.assign(updates, {
        [field]: value.trim(),
      });
    }

    if (
      data.appName !== undefined &&
      !data.appName.trim()
    ) {
      throw new BadRequestException(
        'appName cannot be empty',
      );
    }

    const colorFields: Array<
      keyof GlobalSettingsDocument
    > = [
      'primaryColor',
      'secondaryColor',
      'accentColor',
    ];

    for (const field of colorFields) {
      const value = data[field];

      if (value === undefined) {
        continue;
      }

      if (
        typeof value !== 'string' ||
        !/^#[0-9A-Fa-f]{6}$/.test(value.trim())
      ) {
        throw new BadRequestException(
          `${field} must be a valid hex color like #159447`,
        );
      }

      Object.assign(updates, {
        [field]: value.trim().toUpperCase(),
      });
    }

    if (data.home !== undefined) {
      const allowedModules = ['food', 'grocery'];

      const enabledModules =
        data.home.enabledModules?.filter((module) =>
          allowedModules.includes(module.trim().toLowerCase()),
        ) ?? [];

      const allowedSections = [
        'modules',
        'promo',
        'categories',
        'nearby',
      ];

      const sections =
        data.home.sections
          ?.filter((section) => allowedSections.includes(section.id))
          .map((section) => ({
            id: section.id,
            enabled: section.enabled === true,
            sortOrder:
              Number.isFinite(section.sortOrder) &&
              section.sortOrder > 0
                ? section.sortOrder
                : 1,
          })) ?? [];

      const promoBanner = data.home.promoBanner ?? {};

      updates.home = {
        enabledModules,
        sections,
        promoBanner: {
          enabled: promoBanner.enabled !== false,
          title: promoBanner.title?.trim() ?? 'Fresh deals for you',
          subtitle:
            promoBanner.subtitle?.trim() ??
            'Order your favourites today',
          imageUrl: promoBanner.imageUrl?.trim() ?? '',
          actionType:
            promoBanner.actionType === 'MODULE' ||
            promoBanner.actionType === 'CATEGORY'
              ? promoBanner.actionType
              : 'NONE',
          actionValue: promoBanner.actionValue?.trim() ?? '',
        },
      };
    }

    if (data.content !== undefined) {
      const current = (await settingsRef.get()).data()?.content ?? {};
      updates.content = this.mergeContent(current, data.content);
    }

    updates.updatedAt = new Date().toISOString();

    await settingsRef.set(updates, {
      merge: true,
    });

    const updatedSnapshot = await settingsRef.get();

    return updatedSnapshot.data();
  }
  private getDefaultContent() {
    return {
      terms: { title: 'Terms & Conditions', content: '', version: '1.0', isEnabled: true },
      privacy: { title: 'Privacy Policy', content: '', version: '1.0', isEnabled: true },
      refundPolicy: { title: 'Refund & Cancellation Policy', content: '', version: '1.0', isEnabled: true },
      deliveryPolicy: { title: 'Delivery Policy', content: '', version: '1.0', isEnabled: true },
      about: { title: 'About Us', content: '', isEnabled: true },
      support: { title: 'Contact Support', content: '', phone: '', email: '', whatsapp: '', workingHours: '', isEnabled: true },
      permissions: { title: 'App Permissions', location: 'Location is used to determine service availability and delivery address.', notifications: 'Notifications are used to provide order and delivery updates.', camera: 'Camera access is used only when a feature requires taking a photo.', photos: 'Photo access is used only when a feature requires selecting an image.', isEnabled: true },
    };
  }
  private mergeContent(current: Record<string, any>, incoming: Record<string, any>) {
    const defaults = this.getDefaultContent() as Record<string, any>;
    const merged: Record<string, any> = { ...defaults, ...current, ...incoming };
    for (const key of Object.keys(defaults)) merged[key] = { ...defaults[key], ...(current[key] ?? {}), ...(incoming[key] ?? {}) };
    return merged;
  }
  private validateVersion(value: string, field: string) {
    if (typeof value !== 'string') {
      throw new BadRequestException(`${field} must be a string`);
    }

    const version = value.trim();

    if (!/^\d+\.\d+\.\d+$/.test(version)) {
      throw new BadRequestException(`${field} must use x.y.z format`);
    }

    return version;
  }
  private validateZoneCoverage(
    latitude: number,
    longitude: number,
    radiusKm: number,
  ): void {
    if (
      typeof latitude !== 'number' ||
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90
    ) {
      throw new BadRequestException(
        'centerLatitude must be between -90 and 90',
      );
    }

    if (
      typeof longitude !== 'number' ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new BadRequestException(
        'centerLongitude must be between -180 and 180',
      );
    }

    if (
      typeof radiusKm !== 'number' ||
      !Number.isFinite(radiusKm) ||
      radiusKm <= 0
    ) {
      throw new BadRequestException('radiusKm must be greater than 0');
    }
  }
}
