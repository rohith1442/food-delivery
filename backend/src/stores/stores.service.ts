import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';
import { assertOwnedFirebaseImageUrl } from '../uploads/image-url.util.js';

export interface CreateStoreRequest {
  name: string;
  moduleId: string;
  zoneId: string;
  address: string;
  latitude?: number;
  longitude?: number;
  minimumOrder?: number;
}

export interface UpdateStoreRequest {
  name?: string;
  moduleId?: string;
  zoneId?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  minimumOrder?: number;
}

export interface StoreDocument {
  id: string;
  merchantId: string;
  name: string;
  moduleId: string;
  zoneId: string;
  address: string;
  latitude: number | null;
  longitude: number | null;
  minimumOrder: number;
  imageUrl: string | null;
  ratingAverage: number;
  ratingCount: number;
  isActive: boolean;
  isOpen: boolean;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class StoresService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async createStore(
    merchantId: string,
    data: CreateStoreRequest,
  ) {
    if (!data.name?.trim()) {
      throw new BadRequestException(
        'Store name is required',
      );
    }

    if (!data.moduleId?.trim()) {
      throw new BadRequestException(
        'Module is required',
      );
    }

    if (!data.zoneId?.trim()) {
      throw new BadRequestException(
        'Zone is required',
      );
    }

    if (!data.address?.trim()) {
      throw new BadRequestException(
        'Store address is required',
      );
    }

    const db =
        this.firebaseService.getFirestore();

    // MVP: one store per merchant.
    const existingStoreSnapshot = await db
        .collection('stores')
        .where('merchantId', '==', merchantId)
        .limit(1)
        .get();

    if (!existingStoreSnapshot.empty) {
      throw new BadRequestException(
        'Merchant already has a store',
      );
    }

    const storeRef =
        db.collection('stores').doc();

    const now = new Date().toISOString();

    const store: StoreDocument = {
      id: storeRef.id,
      merchantId,
      name: data.name.trim(),
      moduleId: data.moduleId.trim(),
      zoneId: data.zoneId.trim(),
      address: data.address.trim(),
      latitude: data.latitude ?? null,
      longitude: data.longitude ?? null,
      minimumOrder: data.minimumOrder ?? 0,
      imageUrl: null,
      ratingAverage: 0,
      ratingCount: 0,
      // A store becomes discoverable only after merchant KYC and settlement
      // activation have both completed.
      isActive: false,
      isOpen: true,
      createdAt: now,
      updatedAt: now,
    };

    await storeRef.set(store);

    return {
      success: true,
      store,
    };
  }

  async getMerchantStore(
    merchantId: string,
  ) {
    const db =
        this.firebaseService.getFirestore();

    const snapshot = await db
        .collection('stores')
        .where('merchantId', '==', merchantId)
        .limit(1)
        .get();

    if (snapshot.empty) {
      throw new NotFoundException(
        'Store not found',
      );
    }

    const doc = snapshot.docs[0];

    return {
      success: true,
      store: {
        id: doc.id,
        ...doc.data(),
      },
    };
  }

  async updateStoreImage(
    merchantId: string,
    imageUrl: string,
  ) {
    if (!imageUrl?.trim()) {
      throw new BadRequestException(
        'Store image URL is required',
      );
    }

    const db = this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('stores')
      .where('merchantId', '==', merchantId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new NotFoundException('Store not found');
    }

    const storeDoc = snapshot.docs[0];
    const normalizedImageUrl = imageUrl.trim();
    assertOwnedFirebaseImageUrl(
      normalizedImageUrl,
      this.firebaseService.getStorage().bucket().name,
      'stores',
      merchantId,
    );
    const updatedAt = new Date().toISOString();

    await storeDoc.ref.update({
      imageUrl: normalizedImageUrl,
      updatedAt,
    });

    return {
      success: true,
      storeId: storeDoc.id,
      imageUrl: normalizedImageUrl,
      updatedAt,
    };
  }

  async updateStoreStatus(
    merchantId: string,
    storeId: string,
    isOpen: boolean,
  ) {
    const db =
        this.firebaseService.getFirestore();

    const storeRef =
        db.collection('stores').doc(storeId);

    const snapshot = await storeRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Store not found',
      );
    }

    const store =
        snapshot.data() as StoreDocument;

    if (store.merchantId !== merchantId) {
      throw new ForbiddenException(
        'You do not have access to this store',
      );
    }

    const updatedAt =
        new Date().toISOString();

    await storeRef.update({
      isOpen,
      updatedAt,
    });

    return {
      success: true,
      storeId,
      isOpen,
      updatedAt,
    };
  }

  async updateStore(
    merchantId: string,
    storeId: string,
    data: UpdateStoreRequest,
  ) {
    const db = this.firebaseService.getFirestore();
    const storeRef = db.collection('stores').doc(storeId);
    const snapshot = await storeRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Store not found');
    }

    const store = snapshot.data() as StoreDocument;
    if (store.merchantId !== merchantId) {
      throw new ForbiddenException('You do not have access to this store');
    }

    const update: Record<string, unknown> = {
      updatedAt: new Date().toISOString(),
    };

    if (data.name !== undefined) {
      if (!data.name.trim()) {
        throw new BadRequestException('Store name is required');
      }
      update.name = data.name.trim();
    }

    if (data.moduleId !== undefined) {
      if (!data.moduleId.trim()) {
        throw new BadRequestException('Module is required');
      }
      update.moduleId = data.moduleId.trim();
    }

    if (data.zoneId !== undefined) {
      if (!data.zoneId.trim()) {
        throw new BadRequestException('Zone is required');
      }
      update.zoneId = data.zoneId.trim();
    }

    if (data.address !== undefined) {
      if (!data.address.trim()) {
        throw new BadRequestException('Store address is required');
      }
      update.address = data.address.trim();
    }

    if (data.latitude !== undefined || data.longitude !== undefined) {
      if (
        typeof data.latitude !== 'number' ||
        !Number.isFinite(data.latitude) ||
        data.latitude < -90 ||
        data.latitude > 90
      ) {
        throw new BadRequestException('Invalid latitude');
      }

      if (
        typeof data.longitude !== 'number' ||
        !Number.isFinite(data.longitude) ||
        data.longitude < -180 ||
        data.longitude > 180
      ) {
        throw new BadRequestException('Invalid longitude');
      }

      update.latitude = data.latitude;
      update.longitude = data.longitude;
    }

    if (data.minimumOrder !== undefined) {
      if (!Number.isFinite(data.minimumOrder) || data.minimumOrder < 0) {
        throw new BadRequestException('Invalid minimum order');
      }
      update.minimumOrder = data.minimumOrder;
    }

    await storeRef.update(update);
    const updated = await storeRef.get();

    return {
      success: true,
      store: { id: updated.id, ...updated.data() },
    };
  }

  async getStores(
    moduleId?: string,
    zoneId?: string,
    category?: string,
) {
  const db = this.firebaseService.getFirestore();

  if (moduleId?.trim()) {
    const normalizedModuleId =
      moduleId.trim();

    const moduleSnapshot = await db
      .collection('modules')
      .doc(normalizedModuleId)
      .get();

    if (!moduleSnapshot.exists) {
      return [];
    }

    const moduleData =
      moduleSnapshot.data() as {
        isActive?: boolean;
      };

    if (moduleData.isActive !== true) {
      return [];
    }
  }

  const snapshot = await db
    .collection('stores')
    .where('isActive', '==', true)
    .get();

  let stores = snapshot.docs.map((doc) => ({
  ...(doc.data() as StoreDocument),
  id: doc.id,
}));

  if (moduleId?.trim()) {
    const normalizedModuleId =
      moduleId.trim();

    stores = stores.filter(
      (store) =>
        store.moduleId ===
        normalizedModuleId,
    );
  }

  if (zoneId?.trim()) {
    const normalizedZoneId =
      zoneId.trim();

    stores = stores.filter(
      (store) =>
        store.zoneId ===
        normalizedZoneId,
    );
  }

  if (category?.trim()) {
    const normalizedCategory =
      category.trim().toLowerCase();

    const eligibleStoreIds = new Set(
      stores.map((store) => store.id),
    );

    if (eligibleStoreIds.size === 0) {
      return [];
    }

    const categoriesSnapshot = await db
      .collection('categories')
      .where('isActive', '==', true)
      .get();

    const matchingStoreIds = new Set(
      categoriesSnapshot.docs
        .map((doc) => doc.data())
        .filter((categoryData) => {
          const categoryName = categoryData.name
            ?.toString()
            .trim()
            .toLowerCase();

          const storeId = categoryData.storeId?.toString();

          return (
            categoryName === normalizedCategory &&
            storeId != null &&
            eligibleStoreIds.has(storeId)
          );
        })
        .map((categoryData) =>
          categoryData.storeId.toString(),
        ),
    );

    stores = stores.filter((store) =>
      matchingStoreIds.has(store.id),
    );
  }

  return stores;
}

  async getStore(
    storeId: string,
  ) {
    const db =
        this.firebaseService.getFirestore();

    const snapshot = await db
        .collection('stores')
        .doc(storeId)
        .get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Store not found',
      );
    }

    return {
      success: true,
      store: {
        id: snapshot.id,
        ...snapshot.data(),
      },
    };
  }

}
