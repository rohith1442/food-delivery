import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';
import { ZonesService } from '../zones/zones.service.js';

interface CreateAddressRequest {
  label?: string;
  address: string;
  latitude: number;
  longitude: number;
  contactName?: string;
  contactPhone?: string;
}

interface UpdateAddressRequest {
  label?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
}

export interface AddressDocument {
  id: string;
  userId: string;
  label: string;
  address: string;
  contactName: string;
  contactPhone: string;
  latitude: number;
  longitude: number;
  zoneId: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class AddressesService {
  constructor(
    private readonly firebaseService: FirebaseService,
    private readonly zonesService: ZonesService,
  ) {}

  async getAddresses(userId: string) {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('addresses')
      .where('userId', '==', userId)
      .get();

    const addresses = snapshot.docs
      .map((doc) => ({
        ...(doc.data() as AddressDocument),
        id: doc.id,
      }))
      .sort((a, b) => {
        if (a.isDefault === b.isDefault) {
          return b.createdAt.localeCompare(a.createdAt);
        }

        return a.isDefault ? -1 : 1;
      });

    return {
      success: true,
      addresses,
    };
  }

  async createAddress(
    userId: string,
    data: CreateAddressRequest,
  ) {
    if (!data.address?.trim()) {
      throw new BadRequestException(
        'Address is required',
      );
    }

    this.validateCoordinates(
      data.latitude,
      data.longitude,
    );

    const resolution =
      await this.zonesService.resolveZone(
        data.latitude,
        data.longitude,
      );

    if (
      !resolution.serviceable ||
      resolution.zone === null
    ) {
      throw new BadRequestException(
        "We don't deliver to this location yet",
      );
    }

    const db = this.firebaseService.getFirestore();

    const existingSnapshot = await db
      .collection('addresses')
      .where('userId', '==', userId)
      .get();

    const addressRef =
      db.collection('addresses').doc();

    const now = new Date().toISOString();

    const address: AddressDocument = {
      id: addressRef.id,
      userId,
      label: data.label?.trim() || 'Home',
      address: data.address.trim(),
      contactName: data.contactName?.trim() ?? '',
      contactPhone: data.contactPhone?.trim() ?? '',
      latitude: data.latitude,
      longitude: data.longitude,
      zoneId: resolution.zone.id,
      isDefault: existingSnapshot.empty,
      createdAt: now,
      updatedAt: now,
    };

    await addressRef.set(address);

    return {
      success: true,
      address,
    };
  }

  async updateAddress(
    userId: string,
    addressId: string,
    data: UpdateAddressRequest,
  ) {
    const db = this.firebaseService.getFirestore();

    const addressRef =
      db.collection('addresses').doc(addressId);

    const snapshot = await addressRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Address not found',
      );
    }

    const existing =
      snapshot.data() as AddressDocument;

    if (existing.userId !== userId) {
      throw new ForbiddenException(
        'You do not have access to this address',
      );
    }

    const latitude =
      data.latitude ?? existing.latitude;

    const longitude =
      data.longitude ?? existing.longitude;

    this.validateCoordinates(
      latitude,
      longitude,
    );

    if (
      data.address !== undefined &&
      !data.address.trim()
    ) {
      throw new BadRequestException(
        'Address cannot be empty',
      );
    }

    let zoneId = existing.zoneId;

    if (
      data.latitude !== undefined ||
      data.longitude !== undefined
    ) {
      const resolution =
        await this.zonesService.resolveZone(
          latitude,
          longitude,
        );

      if (
        !resolution.serviceable ||
        resolution.zone === null
      ) {
        throw new BadRequestException(
          "We don't deliver to this location yet",
        );
      }

      zoneId = resolution.zone.id;
    }

    const updatedAt = new Date().toISOString();

    const updates: Partial<AddressDocument> = {
      latitude,
      longitude,
      zoneId,
      updatedAt,
    };

    if (data.label !== undefined) {
      updates.label =
        data.label.trim() || 'Home';
    }

    if (data.address !== undefined) {
      updates.address = data.address.trim();
    }

    await addressRef.update(updates);

    const updatedSnapshot =
      await addressRef.get();

    return {
      success: true,
      address: {
        ...(updatedSnapshot.data() as AddressDocument),
        id: updatedSnapshot.id,
      },
    };
  }

  async deleteAddress(
    userId: string,
    addressId: string,
  ) {
    const db = this.firebaseService.getFirestore();

    const addressRef =
      db.collection('addresses').doc(addressId);

    const snapshot = await addressRef.get();

    if (!snapshot.exists) {
      throw new NotFoundException(
        'Address not found',
      );
    }

    const address =
      snapshot.data() as AddressDocument;

    if (address.userId !== userId) {
      throw new ForbiddenException(
        'You do not have access to this address',
      );
    }

    await addressRef.delete();

    if (address.isDefault) {
      const remainingSnapshot = await db
        .collection('addresses')
        .where('userId', '==', userId)
        .limit(1)
        .get();

      if (!remainingSnapshot.empty) {
        await remainingSnapshot.docs[0].ref.update({
          isDefault: true,
          updatedAt: new Date().toISOString(),
        });
      }
    }

    return {
      success: true,
      addressId,
    };
  }

  async setDefaultAddress(
    userId: string,
    addressId: string,
  ) {
    const db = this.firebaseService.getFirestore();

    const targetRef =
      db.collection('addresses').doc(addressId);

    const targetSnapshot =
      await targetRef.get();

    if (!targetSnapshot.exists) {
      throw new NotFoundException(
        'Address not found',
      );
    }

    const target =
      targetSnapshot.data() as AddressDocument;

    if (target.userId !== userId) {
      throw new ForbiddenException(
        'You do not have access to this address',
      );
    }

    const snapshot = await db
      .collection('addresses')
      .where('userId', '==', userId)
      .get();

    const batch = db.batch();
    const now = new Date().toISOString();

    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        isDefault: doc.id === addressId,
        updatedAt: now,
      });
    }

    await batch.commit();

    return {
      success: true,
      addressId,
      isDefault: true,
    };
  }

  private validateCoordinates(
    latitude: number,
    longitude: number,
  ): void {
    if (
      typeof latitude !== 'number' ||
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90
    ) {
      throw new BadRequestException(
        'Invalid latitude',
      );
    }

    if (
      typeof longitude !== 'number' ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new BadRequestException(
        'Invalid longitude',
      );
    }
  }
}
