import React from 'react';

import { ScrollView, Text } from 'react-native';

import {SafeAreaView, SafeAreaProvider} from 'react-native-safe-area-context';

export default function HomeScreen() {
  return (
    <SafeAreaProvider>
      <SafeAreaView>
        <ScrollView>
          <Text>Upcoming</Text>
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}