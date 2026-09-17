import { Injectable, OnModuleInit } from '@nestjs/common';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, Auth } from 'firebase-admin/auth';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getStorage, Storage } from 'firebase-admin/storage';
import { getMessaging, Messaging } from 'firebase-admin/messaging';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private firestore!: Firestore;
  private auth!: Auth;
  private storage!: Storage;
  private messaging!: Messaging;

  onModuleInit() {
    const apps = getApps();

    const app =
      apps.length > 0
        ? apps[0]
        : initializeApp({
            credential: cert({
              projectId: process.env.FIREBASE_PROJECT_ID,
              clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
              privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(
                /\\n/g,
                '\n',
              ),
            }),
            storageBucket:
              process.env.FIREBASE_STORAGE_BUCKET ??
              'food-delivery-e5521.firebasestorage.app',
          });

    this.firestore = getFirestore(app);
    this.auth = getAuth(app);
    this.storage = getStorage(app);
    this.messaging = getMessaging(app);
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

  getMessaging(): Messaging {
    return this.messaging;
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