import React from 'react';

import { ScrollView, Text } from 'react-native';

import {SafeAreaView, SafeAreaProvider} from 'react-native-safe-area-context';

export default function Grades() {
  return (
    <SafeAreaProvider>
      <SafeAreaView>
        <ScrollView>
          <Text>Grades</Text>
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}