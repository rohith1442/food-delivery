import { Injectable } from '@nestjs/common';

import { FirebaseService } from '../firebase/firebase.service.js';

interface ModuleDocument {
  name?: string;
  description?: string;
  imageUrl?: string;
  isActive?: boolean;
  sortOrder?: number;
}

@Injectable()
export class ModulesService {
  constructor(
    private readonly firebaseService: FirebaseService,
  ) {}

  async getModules() {
    const db = this.firebaseService.getFirestore();

    const snapshot = await db.collection('modules').get();

    return snapshot.docs
      .map((doc) => {
        const data = doc.data() as ModuleDocument;

        return {
          id: doc.id,
          name: data.name ?? doc.id,
          description: data.description ?? '',
          imageUrl: data.imageUrl ?? '',
          isActive: data.isActive === true,
          sortOrder: data.sortOrder ?? 999,
        };
      })
      .filter((module) => module.isActive)
      .sort((a, b) => a.sortOrder - b.sortOrder);
  }
}
