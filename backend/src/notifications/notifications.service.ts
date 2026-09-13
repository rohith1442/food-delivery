import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import { createHash } from 'node:crypto';

import { FirebaseService } from '../firebase/firebase.service.js';

interface PushNotification {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationsService {
  private readonly logger =
    new Logger(NotificationsService.name);

  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async createNotification(
    uid: string,
    notification: PushNotification,
  ) {
    const db = this.firebaseService.getFirestore();
    const ref = db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc();
    const record = {
      id: ref.id,
      title: notification.title,
      body: notification.body,
      data: notification.data ?? {},
      isRead: false,
      createdAt: new Date().toISOString(),
    };

    await ref.set(record);
    return record;
  }

  async sendToToken(
    token: string,
    notification: PushNotification,
  ): Promise<boolean> {
    if (!token?.trim()) {
      return false;
    }

    try {
      const messaging =
        this.firebaseService.getMessaging();

      await messaging.send({
        token,

        notification: {
          title: notification.title,
          body: notification.body,
        },

        data: notification.data ?? {},

        android: {
          priority: 'high',

          notification: {
            channelId: 'orders',
          },
        },

        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

      return true;
    } catch (error) {
      this.logger.error(
        'Failed to send FCM notification',
        error instanceof Error
          ? error.stack
          : String(error),
      );

      return false;
    }
  }
  async sendToUser(
  uid: string,
  notification: PushNotification,
): Promise<void> {
  try {
    await this.createNotification(uid, notification);

    const db = this.firebaseService.getFirestore();

    const devicesSnapshot = await db
      .collection('users')
      .doc(uid)
      .collection('devices')
      .get();

    if (devicesSnapshot.empty) {
      this.logger.log(
        `No FCM devices registered uid=${uid}`,
      );
      return;
    }

    const tokens = devicesSnapshot.docs
      .map((doc) => doc.data().token as string | undefined)
      .filter(
        (token): token is string =>
          typeof token === 'string' &&
          token.trim().length > 0,
      );

    if (tokens.length === 0) {
      return;
    }

    const messaging =
      this.firebaseService.getMessaging();

    const response =
      await messaging.sendEachForMulticast({
        tokens,

        notification: {
          title: notification.title,
          body: notification.body,
        },

        data: notification.data ?? {},

        android: {
          priority: 'high',
          notification: {
            channelId: 'orders',
          },
        },

        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

    this.logger.log(
      `FCM sent uid=${uid} success=${response.successCount} failed=${response.failureCount}`,
    );
  } catch (error) {
    // Notification failure must never fail order creation.
    this.logger.error(
      `Failed to send FCM notification uid=${uid}`,
      error instanceof Error
        ? error.stack
        : String(error),
    );
  }
  }

  async getNotifications(uid: string) {
    const snapshot = await this.firebaseService
      .getFirestore()
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();

    return {
      success: true,
      notifications: snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  }

  async markNotificationRead(uid: string, notificationId: string) {
    const ref = this.firebaseService
      .getFirestore()
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId);
    const snapshot = await ref.get();

    if (!snapshot.exists) {
      throw new NotFoundException('Notification not found');
    }

    await ref.update({isRead: true});
    return {success: true};
  }

  async markAllNotificationsRead(uid: string) {
    const db = this.firebaseService.getFirestore();
    const snapshot = await db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('isRead', '==', false)
      .get();
    const batch = db.batch();

    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {isRead: true});
    }

    await batch.commit();
    return {success: true};
  }
  async registerDeviceToken(
  uid: string,
  data: {
    token: string;
    app: string;
    platform: string;
  },
) {
  const app = data.app?.trim().toUpperCase();
  const platform =
    data.platform?.trim().toUpperCase();

  if (
    !['CUSTOMER', 'MERCHANT', 'DELIVERY'].includes(app)
  ) {
    throw new BadRequestException(
      'Invalid application',
    );
  }

  if (!['ANDROID', 'IOS'].includes(platform)) {
    throw new BadRequestException(
      'Invalid platform',
    );
  }

  const token = data.token.trim();

  const db =
    this.firebaseService.getFirestore();

  const userRef =
    db.collection('users').doc(uid);

  const userSnapshot =
    await userRef.get();

  if (!userSnapshot.exists) {
    throw new NotFoundException(
      'User not found',
    );
  }

  const user = userSnapshot.data();

  if (!user) {
    throw new NotFoundException(
      'User not found',
    );
  }

  if (user.role !== app) {
    throw new BadRequestException(
      'Application does not match user role',
    );
  }

  /*
   * Use a hash instead of the FCM token itself
   * as the Firestore document ID.
   */
  const tokenHash = createHash('sha256')
    .update(token)
    .digest('hex');

  const now = new Date().toISOString();

  await userRef
    .collection('devices')
    .doc(tokenHash)
    .set(
      {
        token,
        app,
        platform,

        createdAt: now,
        updatedAt: now,
      },
      {
        merge: true,
      },
    );

  this.logger.log(
    `FCM device registered uid=${uid} app=${app} platform=${platform}`,
  );

  return {
    success: true,
  };
}
}
