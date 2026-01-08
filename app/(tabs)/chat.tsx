import React from 'react';

import { ScrollView, Text } from 'react-native';

import {SafeAreaView, SafeAreaProvider} from 'react-native-safe-area-context';

export default function Chat() {
  return (
    <SafeAreaProvider>
      <SafeAreaView>
        <ScrollView>
          <Text>Chat</Text>
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}