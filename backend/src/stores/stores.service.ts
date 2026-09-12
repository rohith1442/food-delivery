import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

export interface CreateStoreRequest {
  name: string;
  moduleId: string;
  zoneId: string;
  address: string;
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
      isActive: true,
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
