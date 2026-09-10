import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

interface ZoneDocument {
  name?: string;
  city?: string;
  state?: string;
  centerLatitude?: number;
  centerLongitude?: number;
  radiusKm?: number;
  isActive?: boolean;
}

@Injectable()
export class ZonesService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async resolveZone(
    latitude: number,
    longitude: number,
  ) {
    this.validateCoordinates(latitude, longitude);

    const db =
      this.firebaseService.getFirestore();

    const snapshot = await db
      .collection('zones')
      .where('isActive', '==', true)
      .get();

    let matchedZone:
      | {
          id: string;
          data: ZoneDocument;
          distanceKm: number;
        }
      | undefined;

    for (const doc of snapshot.docs) {
      const zone = doc.data() as ZoneDocument;

      if (
        typeof zone.centerLatitude !== 'number' ||
        typeof zone.centerLongitude !== 'number' ||
        typeof zone.radiusKm !== 'number' ||
        zone.radiusKm <= 0
      ) {
        continue;
      }

      const distanceKm =
        this.calculateDistanceKm(
          latitude,
          longitude,
          zone.centerLatitude,
          zone.centerLongitude,
        );

      if (distanceKm > zone.radiusKm) {
        continue;
      }

      if (
        matchedZone === undefined ||
        distanceKm < matchedZone.distanceKm
      ) {
        matchedZone = {
          id: doc.id,
          data: zone,
          distanceKm,
        };
      }
    }

    if (matchedZone === undefined) {
      return {
        serviceable: false,
        zone: null,
      };
    }

    return {
      serviceable: true,
      zone: {
        id: matchedZone.id,
        name: matchedZone.data.name ?? '',
        city: matchedZone.data.city ?? '',
        state: matchedZone.data.state ?? '',
        radiusKm: matchedZone.data.radiusKm,
      },
    };
  }

  private validateCoordinates(
    latitude: number,
    longitude: number,
  ): void {
    if (
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90
    ) {
      throw new BadRequestException(
        'Invalid latitude',
      );
    }

    if (
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new BadRequestException(
        'Invalid longitude',
      );
    }
  }

  private calculateDistanceKm(
    latitude1: number,
    longitude1: number,
    latitude2: number,
    longitude2: number,
  ): number {
    const earthRadiusKm = 6371;

    const latitudeDifference =
      this.toRadians(latitude2 - latitude1);

    const longitudeDifference =
      this.toRadians(longitude2 - longitude1);

    const firstLatitude =
      this.toRadians(latitude1);

    const secondLatitude =
      this.toRadians(latitude2);

    const a =
      Math.sin(latitudeDifference / 2) ** 2 +
      Math.cos(firstLatitude) *
        Math.cos(secondLatitude) *
        Math.sin(longitudeDifference / 2) ** 2;

    const c =
      2 *
      Math.atan2(
        Math.sqrt(a),
        Math.sqrt(1 - a),
      );

    return earthRadiusKm * c;
  }

  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
