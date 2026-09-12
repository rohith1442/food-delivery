import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

export interface StoreDocument {
  id: string;
  merchantId: string;
  name: string;
  moduleId: string;
  zoneId: string;
  address: string;
  imageUrl?: string | null;
  isActive: boolean;
  isOpen: boolean;
}

export interface CategoryDocument {
  id: string;
  storeId: string;
  merchantId: string;
  moduleId: string;
  name: string;
  imageUrl?: string | null;
  isActive: boolean;
}

export interface ProductDocument {
  id: string;
  storeId: string;
  merchantId: string;
  moduleId: string;
  categoryId: string;
  name: string;
  description?: string;
  price: number;
  stock: number;
  imageUrl?: string | null;
  isAvailable: boolean;
}

@Injectable()
export class SearchService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async search(zoneId?: string, query?: string) {
    const normalizedZoneId = zoneId?.trim();
    const normalizedQuery = query?.trim().toLowerCase();

    if (!normalizedZoneId) {
      throw new BadRequestException('zoneId is required');
    }

    if (!normalizedQuery) {
      return {
        success: true,
        stores: [],
        categories: [],
        products: [],
      };
    }

    const db = this.firebaseService.getFirestore();

    const [
      settingsSnapshot,
      modulesSnapshot,
      storesSnapshot,
      categoriesSnapshot,
    ] = await Promise.all([
      db.collection('settings').doc('global').get(),
      db.collection('modules').get(),
      db.collection('stores').where('isActive', '==', true).get(),
      db.collection('categories').where('isActive', '==', true).get(),
    ]);

    const settings = settingsSnapshot.data();
    const configuredModules = settings?.home?.enabledModules;

    const enabledModules = new Set<string>(
      Array.isArray(configuredModules)
        ? configuredModules
            .map((value: unknown) =>
              String(value).trim().toLowerCase(),
            )
            .filter(Boolean)
        : ['food', 'grocery'],
    );

    const activeModules = new Set(
      modulesSnapshot.docs
        .filter((doc) => doc.data().isActive === true)
        .map((doc) => doc.id.toLowerCase()),
    );

    const allowedModules = new Set(
      [...enabledModules].filter((moduleId) =>
        activeModules.has(moduleId),
      ),
    );

    const eligibleStores = storesSnapshot.docs
      .map((doc) => ({
        ...(doc.data() as StoreDocument),
        id: doc.id,
      }))
      .filter(
        (store) =>
          store.zoneId === normalizedZoneId &&
          allowedModules.has(store.moduleId?.toLowerCase()),
      );

    const eligibleStoreIds = new Set(
      eligibleStores.map((store) => store.id),
    );

    const matchedStores = eligibleStores.filter(
      (store) =>
        this.includes(store.name, normalizedQuery) ||
        this.includes(store.address, normalizedQuery),
    );

    const categories = categoriesSnapshot.docs
      .map((doc) => ({
        ...(doc.data() as CategoryDocument),
        id: doc.id,
      }))
      .filter(
        (category) =>
          eligibleStoreIds.has(category.storeId) &&
          allowedModules.has(category.moduleId?.toLowerCase()),
      );

    const matchedCategories = categories.filter((category) =>
      this.includes(category.name, normalizedQuery),
    );

    const productResults: Array<
      ProductDocument & {
        storeName: string;
        storeAddress: string;
        storeIsOpen: boolean;
      }
    > = [];

    await Promise.all(
      eligibleStores.map(async (store) => {
        const productSnapshot = await db
          .collection('stores')
          .doc(store.id)
          .collection('products')
          .where('isAvailable', '==', true)
          .get();

        for (const doc of productSnapshot.docs) {
          const product = {
            ...(doc.data() as ProductDocument),
            id: doc.id,
          };

          if (product.stock <= 0) {
            continue;
          }

          const matches =
            this.includes(product.name, normalizedQuery) ||
            this.includes(product.description, normalizedQuery);

          if (!matches) {
            continue;
          }

          productResults.push({
            ...product,
            storeName: store.name,
            storeAddress: store.address,
            storeIsOpen: store.isOpen === true,
          });
        }
      }),
    );

    return {
      success: true,
      stores: matchedStores,
      categories: this.dedupeCategories(matchedCategories),
      products: productResults,
    };
  }

  private includes(
    value: string | null | undefined,
    query: string,
  ) {
    return (
      value?.toString().trim().toLowerCase().includes(query) === true
    );
  }

  private dedupeCategories(categories: CategoryDocument[]) {
    const unique = new Map<string, CategoryDocument>();

    for (const category of categories) {
      const key =
        `${category.moduleId}:` + category.name.trim().toLowerCase();

      if (!unique.has(key)) {
        unique.set(key, category);
      }
    }

    return [...unique.values()];
  }
}
