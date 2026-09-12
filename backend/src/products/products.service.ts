import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';
import { assertOwnedFirebaseImageUrl } from '../uploads/image-url.util.js';

export interface CreateProductRequest {
  name: string;
  description?: string;
  categoryId: string;
  price: number;
  stock?: number;
  imageUrl?: string;
}

export interface ProductDocument {
  id: string;
  storeId: string;
  merchantId: string;
  moduleId: string;
  categoryId: string;
  name: string;
  description: string;
  price: number;
  stock: number;
  imageUrl: string | null;
  isAvailable: boolean;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class ProductsService {
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

  private async validateCategory(
    categoryId: string,
    storeId: string,
  ) {
    const db =
      this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('categories')
      .doc(categoryId)
      .get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Category not found',
      );
    }

    const category = snapshot.data();

    if (category?.storeId !== storeId) {
      throw new BadRequestException(
        'Category does not belong to this store',
      );
    }

    if (category?.isActive !== true) {
      throw new BadRequestException(
        'Category is not active',
      );
    }
  }

  async createProduct(
    merchantId: string,
    data: CreateProductRequest,
  ) {
    if (!data.name?.trim()) {
      throw new BadRequestException(
        'Product name is required',
      );
    }

    if (!data.categoryId?.trim()) {
      throw new BadRequestException(
        'Category is required',
      );
    }

    if (
      typeof data.price !== 'number' ||
      data.price < 0
    ) {
      throw new BadRequestException(
        'Valid product price is required',
      );
    }

    if (
      data.stock !== undefined &&
      (
        typeof data.stock !== 'number' ||
        data.stock < 0
      )
    ) {
      throw new BadRequestException(
        'Stock cannot be negative',
      );
    }

    const store =
      await this.getMerchantStore(
        merchantId,
      );

    await this.validateCategory(
      data.categoryId,
      store.id,
    );

    const db =
      this.firebaseService.getFirestore();

    const productRef = db
      .collection('stores')
      .doc(store.id)
      .collection('products')
      .doc();

    const now =
      new Date().toISOString();

    const stock = data.stock ?? 0;
    const normalizedImageUrl = data.imageUrl?.trim() || null;

    if (normalizedImageUrl) {
      assertOwnedFirebaseImageUrl(
        normalizedImageUrl,
        this.firebaseService.getStorage().bucket().name,
        'products',
        merchantId,
      );
    }

    const product: ProductDocument = {
      id: productRef.id,
      storeId: store.id,
      merchantId,
      moduleId: store.moduleId,
      categoryId: data.categoryId,
      name: data.name.trim(),
      description:
        data.description?.trim() ?? '',
      price: data.price,
      stock,
      imageUrl: normalizedImageUrl,
      isAvailable: stock > 0,
      createdAt: now,
      updatedAt: now,
    };

    await productRef.set(product);

    return {
      success: true,
      product,
    };
  }

  async getMerchantProducts(
    merchantId: string,
  ) {
    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const db =
      this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('stores')
      .doc(store.id)
      .collection('products')
      .get();

    const products = snapshot.docs.map(
      (doc) => ({
        id: doc.id,
        ...doc.data(),
      }) as ProductDocument,
    );

    products.sort(
      (a, b) =>
        b.createdAt.localeCompare(
          a.createdAt,
        ),
    );

    return {
      success: true,
      storeId: store.id,
      products,
    };
  }

  async updateProduct(
    merchantId: string,
    productId: string,
    data: {
      name?: string;
      description?: string;
      categoryId?: string;
      price?: number;
      stock?: number;
      imageUrl?: string | null;
    },
  ) {
    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const db =
      this.firebaseService.getFirestore();

    const productRef = db
      .collection('stores')
      .doc(store.id)
      .collection('products')
      .doc(productId);

    const snapshot =
      await productRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Product not found',
      );
    }

    const product =
      snapshot.data() as ProductDocument;

    if (
      product.merchantId !== merchantId
    ) {
      throw new ForbiddenException(
        'You do not have access to this product',
      );
    }

    const updates: Record<string, unknown> = {
      updatedAt:
        new Date().toISOString(),
    };

    if (data.name !== undefined) {
      if (!data.name.trim()) {
        throw new BadRequestException(
          'Product name cannot be empty',
        );
      }

      updates.name = data.name.trim();
    }

    if (data.description !== undefined) {
      updates.description =
        data.description.trim();
    }

    if (data.categoryId !== undefined) {
      await this.validateCategory(
        data.categoryId,
        store.id,
      );

      updates.categoryId =
        data.categoryId;
    }

    if (data.price !== undefined) {
      if (
        typeof data.price !== 'number' ||
        data.price < 0
      ) {
        throw new BadRequestException(
          'Invalid product price',
        );
      }

      updates.price = data.price;
    }

    if (data.stock !== undefined) {
      if (
        typeof data.stock !== 'number' ||
        data.stock < 0
      ) {
        throw new BadRequestException(
          'Invalid product stock',
        );
      }

      updates.stock = data.stock;

      if (data.stock === 0) {
        updates.isAvailable = false;
      }
    }

    if (data.imageUrl !== undefined) {
      const normalizedImageUrl = data.imageUrl?.trim() || null;

      if (normalizedImageUrl) {
        assertOwnedFirebaseImageUrl(
          normalizedImageUrl,
          this.firebaseService.getStorage().bucket().name,
          'products',
          merchantId,
        );
      }

      updates.imageUrl = normalizedImageUrl;
    }

    await productRef.update(updates);

    const updatedSnapshot =
      await productRef.get();

    return {
      success: true,
      product: {
        id: updatedSnapshot.id,
        ...updatedSnapshot.data(),
      },
    };
  }

  async updateAvailability(
    merchantId: string,
    productId: string,
    isAvailable: boolean,
  ) {
    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const db =
      this.firebaseService.getFirestore();

    const productRef = db
      .collection('stores')
      .doc(store.id)
      .collection('products')
      .doc(productId);

    const snapshot =
      await productRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Product not found',
      );
    }

    const product =
      snapshot.data() as ProductDocument;

    if (
      product.merchantId !== merchantId
    ) {
      throw new ForbiddenException(
        'You do not have access to this product',
      );
    }

    if (
      isAvailable &&
      product.stock <= 0
    ) {
      throw new BadRequestException(
        'Product with zero stock cannot be made available',
      );
    }

    const updatedAt =
      new Date().toISOString();

    await productRef.update({
      isAvailable,
      updatedAt,
    });

    return {
      success: true,
      productId,
      isAvailable,
      updatedAt,
    };
  }

  async deleteProduct(
    merchantId: string,
    productId: string,
  ) {
    const store =
      await this.getMerchantStore(
        merchantId,
      );

    const db =
      this.firebaseService.getFirestore();

    const productRef = db
      .collection('stores')
      .doc(store.id)
      .collection('products')
      .doc(productId);

    const snapshot =
      await productRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Product not found',
      );
    }

    const product =
      snapshot.data() as ProductDocument;

    if (
      product.merchantId !== merchantId
    ) {
      throw new ForbiddenException(
        'You do not have access to this product',
      );
    }

    await productRef.delete();

    return {
      success: true,
      productId,
    };
  }

  async getStoreProducts(
    storeId: string,
    categoryId?: string,
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
      .collection('stores')
      .doc(storeId)
      .collection('products')
      .get();

    let products = snapshot.docs.map(
      (doc) => ({
        id: doc.id,
        ...doc.data(),
      }) as ProductDocument,
    );

    products = products.filter(
      (product) =>
        product.isAvailable &&
        product.stock > 0,
    );

    if (categoryId) {
      products = products.filter(
        (product) =>
          product.categoryId ===
          categoryId,
      );
    }

    return {
      success: true,
      products,
    };
  }

  async getStoreProduct(
    storeId: string,
    productId: string,
  ) {
    const db =
      this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('stores')
      .doc(storeId)
      .collection('products')
      .doc(productId)
      .get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Product not found',
      );
    }

    return {
      success: true,
      product: {
        id: snapshot.id,
        ...snapshot.data(),
      },
    };
  }
}
