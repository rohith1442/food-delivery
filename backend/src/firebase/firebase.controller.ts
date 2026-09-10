import { Controller, Get } from '@nestjs/common';
import { FirebaseService } from './firebase.service.js';

@Controller('firebase')
export class FirebaseController {
  constructor(private readonly firebaseService: FirebaseService) {}

  @Get('test')
  async testFirestore() {
    const db = this.firebaseService.getFirestore();

    const testRef = db.collection('system').doc('connection-test');

    const data = {
      message: 'Firebase connection is working',
      timestamp: new Date().toISOString(),
    };

    await testRef.set(data);

    const snapshot = await testRef.get();

    return {
      success: snapshot.exists,
      data: snapshot.data(),
    };
  }
}
