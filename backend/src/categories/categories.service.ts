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