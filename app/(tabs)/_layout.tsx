import React from 'react';

import { useColorScheme } from '@/hooks/use-color-scheme';

import { withLayoutContext } from 'expo-router';
import {
  createNativeBottomTabNavigator,
  NativeBottomTabNavigationOptions,
  NativeBottomTabNavigationEventMap,
} from '@bottom-tabs/react-navigation';
import { ParamListBase, TabNavigationState } from '@react-navigation/native';

import { tabIcon } from '@/components/tab-icon';

const BottomTabNavigator = createNativeBottomTabNavigator().Navigator;

const Tabs = withLayoutContext<
  NativeBottomTabNavigationOptions,
  typeof BottomTabNavigator,
  TabNavigationState<ParamListBase>,
  NativeBottomTabNavigationEventMap
>(BottomTabNavigator);

export default function TabLayout() {
  const colorScheme = useColorScheme();

  return (
    <Tabs
      hapticFeedbackEnabled={true}
      sidebarAdaptable={true}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Upcoming",
          tabBarIcon: tabIcon({ ios: "clock", android: "upcoming" }),
        }}
      />
      <Tabs.Screen
        name="schedule"
        options={{
          title: "Schedule",
          tabBarIcon: tabIcon({ ios: "calendar", android: "schedule" }),
        }}
      />
      <Tabs.Screen
        name="grades"
        options={{
          title: "Grades",
          tabBarIcon: tabIcon({ ios: "chart.bar.xaxis", android: "grades" }),
        }}
      />
      <Tabs.Screen
        name="chat"
        options={{
          title: "Chat",
          tabBarIcon: tabIcon({ ios: "bubble", android: "chat" }),
        }}
      />
    </Tabs>
  );
}
