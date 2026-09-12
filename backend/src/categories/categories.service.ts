import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

export interface CreateCategoryRequest {
  name: string;
  sortOrder?: number;
}

export interface CategoryDocument {
  id: string;
  storeId: string;
  merchantId: string;
  moduleId: string;
  name: string;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class CategoriesService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  private async getMerchantStore(
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
        'Merchant store not found',
      );
    }

    const doc = snapshot.docs[0];

    return {
      id: doc.id,
      ...doc.data(),
    } as {
      id: string;
      merchantId: string;
      moduleId: string;
    };
  }

  async createCategory(
    merchantId: string,
    data: CreateCategoryRequest,
  ) {
    if (!data.name?.trim()) {
      throw new BadRequestException(
        'Category name is required',
      );
    }

    const db =
      this.firebaseService.getFirestore();

    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const existingSnapshot = await db
      .collection('categories')
      .where('storeId', '==', store.id)
      .get();

    const duplicate =
      existingSnapshot.docs.some((doc) => {
        const category = doc.data();

        return (
          category.name
            ?.toString()
            .trim()
            .toLowerCase() ===
          data.name.trim().toLowerCase()
        );
      });

    if (duplicate) {
      throw new BadRequestException(
        'Category already exists',
      );
    }

    const categoryRef =
      db.collection('categories').doc();

    const now = new Date().toISOString();

    const category: CategoryDocument = {
      id: categoryRef.id,
      storeId: store.id,
      merchantId,
      moduleId: store.moduleId,
      name: data.name.trim(),
      imageUrl: null,
      sortOrder: data.sortOrder ?? 0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    await categoryRef.set(category);

    return {
      success: true,
      category,
    };
  }

  async getMerchantCategories(
    merchantId: string,
  ) {
    const db =
      this.firebaseService.getFirestore();

    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const snapshot = await db
      .collection('categories')
      .where('storeId', '==', store.id)
      .get();

    const categories =
      snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as CategoryDocument[];

    categories.sort(
      (a, b) =>
        a.sortOrder - b.sortOrder ||
        a.name.localeCompare(b.name),
    );

    return {
      success: true,
      categories,
    };
  }

  async updateCategory(
    merchantId: string,
    categoryId: string,
    data: {
      name?: string;
      sortOrder?: number;
      isActive?: boolean;
    },
  ) {
    const db =
      this.firebaseService.getFirestore();

    const categoryRef = db
      .collection('categories')
      .doc(categoryId);

    const snapshot =
      await categoryRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Category not found',
      );
    }

    const category =
      snapshot.data() as CategoryDocument;

    if (
      category.merchantId !== merchantId
    ) {
      throw new ForbiddenException(
        'You do not have access to this category',
      );
    }

    const updates: Record<string, unknown> = {
      updatedAt: new Date().toISOString(),
    };

    if (data.name !== undefined) {
      if (!data.name.trim()) {
        throw new BadRequestException(
          'Category name cannot be empty',
        );
      }

      updates.name = data.name.trim();
    }

    if (data.sortOrder !== undefined) {
      updates.sortOrder = data.sortOrder;
    }

    if (data.isActive !== undefined) {
      updates.isActive = data.isActive;
    }

    await categoryRef.update(updates);

    return {
      success: true,
      categoryId,
      ...updates,
    };
  }

  async updateCategoryImage(
    merchantId: string,
    categoryId: string,
    imageUrl: string,
  ) {
    const normalizedImageUrl = imageUrl?.trim();

    if (!normalizedImageUrl) {
      throw new BadRequestException(
        'Category image URL is required',
      );
    }

    const db = this.firebaseService.getFirestore();

    const categoryRef = db
      .collection('categories')
      .doc(categoryId);

    const snapshot = await categoryRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Category not found');
    }

    const category = snapshot.data() as CategoryDocument;

    if (category.merchantId !== merchantId) {
      throw new ForbiddenException(
        'You cannot update this category',
      );
    }

    const updatedAt = new Date().toISOString();

    await categoryRef.update({
      imageUrl: normalizedImageUrl,
      updatedAt,
    });

    return {
      success: true,
      categoryId,
      imageUrl: normalizedImageUrl,
      updatedAt,
    };
  }

  async getCategories(
    moduleId?: string,
    zoneId?: string,
  ) {
    const db = this.firebaseService.getFirestore();

    const normalizedModuleId = moduleId?.trim();
    const normalizedZoneId = zoneId?.trim();

    if (normalizedModuleId) {
      const moduleSnapshot = await db
        .collection('modules')
        .doc(normalizedModuleId)
        .get();

      if (!moduleSnapshot.exists) {
        return {
          success: true,
          categories: [],
        };
      }

      const moduleData = moduleSnapshot.data() as {
        isActive?: boolean;
      };

      if (moduleData.isActive !== true) {
        return {
          success: true,
          categories: [],
        };
      }
    }

    const storesSnapshot = await db
      .collection('stores')
      .where('isActive', '==', true)
      .get();

    const eligibleStoreIds = new Set(
      storesSnapshot.docs
        .map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }))
        .filter((store: any) => {
          if (
            normalizedModuleId &&
            store.moduleId !== normalizedModuleId
          ) {
            return false;
          }

          if (
            normalizedZoneId &&
            store.zoneId !== normalizedZoneId
          ) {
            return false;
          }

          return true;
        })
        .map((store) => store.id),
    );

    if (eligibleStoreIds.size === 0) {
      return {
        success: true,
        categories: [],
      };
    }

    const categoriesSnapshot = await db
      .collection('categories')
      .where('isActive', '==', true)
      .get();

    const categories = categoriesSnapshot.docs
      .map(
        (doc) =>
          ({
            id: doc.id,
            ...doc.data(),
          }) as CategoryDocument,
      )
      .filter((category) =>
        eligibleStoreIds.has(category.storeId),
      );

    /*
     * Categories currently belong to stores.
     *
     * For Home discovery, multiple stores may
     * contain categories with the same name.
     * Deduplicate them by normalized name.
     */
    const uniqueCategories = new Map<
      string,
      {
        name: string;
        moduleId: string;
        imageUrl: string | null;
        sortOrder: number;
        storeCount: number;
      }
    >();

    for (const category of categories) {
      const key = category.name.trim().toLowerCase();

      const existing = uniqueCategories.get(key);

      if (existing) {
        existing.storeCount += 1;
        existing.sortOrder = Math.min(
          existing.sortOrder,
          category.sortOrder,
        );

        if (!existing.imageUrl && category.imageUrl) {
          existing.imageUrl = category.imageUrl;
        }

        continue;
      }

      uniqueCategories.set(key, {
        name: category.name,
        moduleId: category.moduleId,
        imageUrl: category.imageUrl ?? null,
        sortOrder: category.sortOrder,
        storeCount: 1,
      });
    }

    const result = Array.from(uniqueCategories.values());

    result.sort(
      (a, b) =>
        a.sortOrder - b.sortOrder ||
        a.name.localeCompare(b.name),
    );

    return {
      success: true,
      categories: result,
    };
  }

  async getStoreCategories(
    storeId: string,
  ) {
    const db =
      this.firebaseService.getFirestore();

    const storeSnapshot = await db
      .collection('stores')
      .doc(storeId)
      .get();

    if (!storeSnapshot.exists) {
      throw new NotFoundException(
        'Store not found',
      );
    }

    const snapshot = await db
      .collection('categories')
      .where('storeId', '==', storeId)
      .get();

    const categories =
      snapshot.docs
        .map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }) as CategoryDocument)
        .filter(
          (category) =>
            category.isActive,
        );

    categories.sort(
      (a, b) =>
        a.sortOrder - b.sortOrder ||
        a.name.localeCompare(b.name),
    );

    return {
      success: true,
      categories,
    };
  }
}
