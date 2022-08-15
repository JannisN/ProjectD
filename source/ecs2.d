module ecs2;

import utils;

// für dynamisch: sortierte liste
// initial length soll standardmässig in ECSEntry auf 0 initialisiert werden

struct ECSEntry(
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticAddUpdates
) {
    size_t[StaticComponents.length] staticComponents = ~0UL;
    size_t[StaticGeneralUpdates.length] staticGeneralUpdates = ~0UL;
    size_t[StaticSpecificUpdates.length] staticSpecificUpdates = ~0UL;
    size_t[StaticAddUpdates.length] staticAddUpdates = ~0UL;
}

struct ComponentEntry(T) {
    T component;
    size_t entity;
}

struct DynamicECS(
    alias BaseVector,
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticAddUpdates,
    StaticRemoveUpdates
) {
    VectorList!(BaseVector!(ECSEntry!(StaticComponents))) entries;
}