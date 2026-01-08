import React from 'react';

import { ScrollView, Text } from 'react-native';

import {SafeAreaView, SafeAreaProvider} from 'react-native-safe-area-context';

export default function Schedule() {
  return (
    <SafeAreaProvider>
      <SafeAreaView>
        <ScrollView>
          <Text>Schedule</Text>
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}