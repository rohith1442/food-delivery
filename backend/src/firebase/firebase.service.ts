import { Injectable, OnModuleInit } from '@nestjs/common';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, Auth } from 'firebase-admin/auth';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getStorage, Storage } from 'firebase-admin/storage';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private firestore!: Firestore;
  private auth!: Auth;
  private storage!: Storage;

  onModuleInit() {
    const apps = getApps();

    const app =
      apps.length > 0
        ? apps[0]
        : initializeApp({
            credential: cert(
              JSON.parse(
                readFileSync(
                  path.join(
                    path.dirname(fileURLToPath(import.meta.url)),
                    '../../config/firebase-service-account.json',
                  ),
                  'utf-8',
                ),
              ),
            ),
            storageBucket: 'food-delivery-e5521.firebasestorage.app',
          });

    this.firestore = getFirestore(app);
    this.auth = getAuth(app);
    this.storage = getStorage(app);
  }

  getFirestore(): Firestore {
    return this.firestore;
  }

  getAuth(): Auth {
    return this.auth;
  }

  getStorage(): Storage {
    return this.storage;
  }

  async getUserById(
    uid: string,
  ): Promise<Record<string, any> | null> {
    const snapshot = await this.firestore
      .collection('users')
      .doc(uid)
      .get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data() ?? null;
  }
}