module ecs2;

import utils;

// für dynamisch: sortierte liste
// initial length soll standardmässig in ECSEntity auf 0 initialisiert werden

struct ECSEntity(
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

struct VirtualEntity(ECS) {
    ECS* ecs;
    size_t entityId;
    auto ref add(Component)() {
        ecs.addComponent!Component(entityId);
        return this;
    }
    auto ref add(Component)(lazy Component component) {
        ecs.addComponent!Component(entityId, component);
        return this;
    }
}

// später vlt noch static views hinzufügen wie beim anderen design
struct DynamicECS(
    alias BaseVector,
    StaticComponents,
    StaticGeneralUpdates,
    StaticSpecificUpdates,
    StaticAddUpdates,
    StaticRemoveUpdates
) {
    alias ECSType = DynamicECS!(
        BaseVector,
        StaticComponents,
        StaticGeneralUpdates,
        StaticSpecificUpdates,
        StaticAddUpdates,
        StaticRemoveUpdates
    );
    alias Entity = ECSEntity!(
        StaticComponents,
        StaticGeneralUpdates,
        StaticSpecificUpdates,
        StaticAddUpdates
    );
    alias ToList(T) = VectorList!(BaseVector, T);
    alias ComponentLists = ApplyTypeSeq!(ToList, StaticComponents.TypeSeq);

    VectorList!(BaseVector, Entity) entities;
    ComponentLists componentLists;
    // speichert zu welchem entity ein component gehört
    VectorList!(BaseVector, size_t)[ComponentLists.length] componentEntityIds;

    auto ref getComponents(Component)() {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        return componentLists[componentId];
    }
    VirtualEntity!ECSType add() {
        size_t id = entities.addId(Entity());
        return VirtualEntity!ECSType(&this, id);
    }
    void addComponent(Component)(size_t id) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId();
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
    }
    void addComponent(Component)(size_t id, lazy Component component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId(component);
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
    }
}

unittest {
    import std.stdio;
    DynamicECS!(
        Vector,
        TypeSeqStruct!(int, double),
        TypeSeqStruct!(),
        TypeSeqStruct!(),
        TypeSeqStruct!(),
        TypeSeqStruct!(),
    ) ecs;
    ecs.add().add!int(3);
    //ecs.getComponents!int().add(3);
    writeln(ecs.getComponents!int()[0]);
}
