import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

export type UserRole =
  | 'CUSTOMER'
  | 'MERCHANT'
  | 'DELIVERY'
  | 'ADMIN';

export type UserStatus =
  | 'PENDING'
  | 'ACTIVE'
  | 'REJECTED'
  | 'SUSPENDED';

@Injectable()
export class AuthService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async verifyToken(token: string) {
    try {
      return await this.firebaseService
        .getAuth()
        .verifyIdToken(token);
    } catch {
      throw new UnauthorizedException(
        'Invalid Firebase ID token',
      );
    }
  }

  async getUser(uid: string) {
    const db =
      this.firebaseService.getFirestore();

    const userRef =
      db.collection('users').doc(uid);

    const snapshot =
      await userRef.get();

    if (!snapshot.exists) {
      return null;
    }

    return {
      id: snapshot.id,
      ...snapshot.data(),
    };
  }

  async registerCustomer(
  uid: string,
  data: {
    phoneNumber?: string | null;
    email?: string | null;
    name?: string;
  },
) {
  const db =
    this.firebaseService.getFirestore();

  const userRef =
    db.collection('users').doc(uid);

  const snapshot =
    await userRef.get();

  if (snapshot.exists) {
    const existing =
      snapshot.data();

    if (
      existing?.role === 'CUSTOMER'
    ) {
      return {
        id: snapshot.id,
        ...existing,
      };
    }

    throw new ConflictException(
      'User profile already exists',
    );
  }

  if (
    !data.email &&
    !data.phoneNumber
  ) {
    throw new BadRequestException(
      'Email or phone number is required',
    );
  }

  const now =
    new Date().toISOString();

  const user = {
    uid,

    email:
      data.email ?? null,

    phoneNumber:
      data.phoneNumber ?? null,

    name:
      data.name?.trim() || null,

    role: 'CUSTOMER' as const,
    status: 'ACTIVE' as const,
    isActive: true,

    createdAt: now,
    updatedAt: now,
  };

  await userRef.set(user);

  return {
    id: uid,
    ...user,
  };
}

  async updateCustomerProfile(
    uid: string,
    data: {
      name?: string;
    },
  ) {
    const db = this.firebaseService.getFirestore();
    const userRef = db.collection('users').doc(uid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException('User profile not found');
    }

    const user = snapshot.data();

    if (user?.role !== 'CUSTOMER') {
      throw new BadRequestException(
        'Only customer profiles can be updated',
      );
    }

    const name = data.name?.trim();

    if (!name) {
      throw new BadRequestException('Name is required');
    }

    if (name.length > 80) {
      throw new BadRequestException(
        'Name must not exceed 80 characters',
      );
    }

    const updatedAt = new Date().toISOString();

    await userRef.update({
      name,
      updatedAt,
    });

    return {
      success: true,
      user: {
        id: snapshot.id,
        ...user,
        name,
        updatedAt,
      },
    };
  }

  async registerMerchant(
    uid: string,
    data: {
      email?: string | null;
      phoneNumber?: string | null;
      name?: string;
      businessName?: string;
    },
  ) {
    return this.registerPrivilegedUser(
      uid,
      'MERCHANT',
      data,
    );
  }

  async registerDelivery(
    uid: string,
    data: {
      email?: string | null;
      phoneNumber?: string | null;
      name?: string;
    },
  ) {
    return this.registerPrivilegedUser(
      uid,
      'DELIVERY',
      data,
    );
  }

  private async registerPrivilegedUser(
    uid: string,
    role: 'MERCHANT' | 'DELIVERY',
    data: {
      email?: string | null;
      phoneNumber?: string | null;
      name?: string;
      businessName?: string;
    },
  ) {
    const db =
      this.firebaseService.getFirestore();

    const userRef =
      db.collection('users').doc(uid);

    const snapshot =
      await userRef.get();

    if (snapshot.exists) {
      const existing =
        snapshot.data();

      if (
        existing?.role === role &&
        existing?.status ===
          'PENDING'
      ) {
        return {
          id: snapshot.id,
          ...existing,
        };
      }

      throw new ConflictException(
        'User profile already exists',
      );
    }

    if (
      !data.email &&
      !data.phoneNumber
    ) {
      throw new BadRequestException(
        'Email or phone number is required',
      );
    }

    const now =
      new Date().toISOString();

    const user = {
      uid,

      email:
        data.email ?? null,

      phoneNumber:
        data.phoneNumber ?? null,

      name:
        data.name?.trim() || null,

      businessName:
        role === 'MERCHANT'
          ? data.businessName?.trim() ||
            null
          : null,

      role,
      status: 'PENDING' as const,
      isActive: false,

      createdAt: now,
      updatedAt: now,
    };

    await userRef.set(user);

    return {
      id: uid,
      ...user,
    };
  }
}
