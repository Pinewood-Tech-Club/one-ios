export function tabIcon({ android }: { android: string }) {
  const iconMap: Record<string, any> = {
    upcoming: require('@/assets/icons/upcoming.svg'),
    schedule: require('@/assets/icons/schedule.svg'),
    grades: require('@/assets/icons/grades.svg'),
    chat: require('@/assets/icons/chat.svg'),
  };

  return () => iconMap[android];
}