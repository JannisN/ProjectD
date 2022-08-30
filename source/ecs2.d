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
    size_t[StaticComponents.length] staticComponents = size_t.max;
    size_t[StaticGeneralUpdates.length] staticGeneralUpdates = size_t.max;
    size_t[StaticSpecificUpdates.length] staticSpecificUpdates = size_t.max;
    size_t[StaticAddUpdates.length] staticAddUpdates = size_t.max;
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
    auto ref remove(Component)() {
        ecs.removeComponent!Component(entityId);
        return this;
    }
}

// später vlt noch static views hinzufügen wie beim anderen design
// soll auch mit compactlist funktionieren(für components); dafür müsste aber compactlist angepasst werden,
// um zu wissen was verschoben wurde
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
    VectorList!(BaseVector, size_t)[StaticAddUpdates.length] addUpdates;

    auto ref getComponents(Component)() {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        return componentLists[componentId];
    }
    auto ref getAddUpdateList(Component)() {
        return addUpdates[findTypes!(Component, StaticAddUpdates.TypeSeq)[0]];
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
        updateAddUpdateList!Component(id);
    }
    void addComponent(Component)(size_t id, lazy Component component) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = componentLists[componentId].addId(component);
        componentEntityIds[componentId].addId(id);
        entities[id].staticComponents[componentId] = componentEntityId;
        updateAddUpdateList!Component(id);
    }
    void removeComponent(Component)(size_t id) {
        enum size_t componentId = findTypes!(Component, StaticComponents.TypeSeq)[0];
        size_t componentEntityId = entities[id].staticComponents[componentId];
        componentLists[componentId].remove(componentEntityId);
        entities[id].staticComponents[componentId] = size_t.max;
        static if (findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0) {
            enum size_t typeId = findTypes!(Component, StaticAddUpdates.TypeSeq)[0];
            size_t addUpdatesId = entities[id].staticAddUpdates[typeId];
            if (addUpdatesId != size_t.max) {
                addUpdates[typeId].removeById(cast(size_t)addUpdatesId);
                entities[id].staticAddUpdates[typeId] = size_t.max;
            }
        }
    }
    void updateAddUpdateList(Component)(size_t id) {
        static if (findTypes!(Component, StaticAddUpdates.TypeSeq).length > 0) {
            enum size_t typeId = findTypes!(Component, StaticAddUpdates.TypeSeq)[0];
            size_t addUpdatesId = addUpdates[typeId].addId(id);
            entities[id].staticAddUpdates[typeId] = addUpdatesId;
        }
    }
}

unittest {
    import std.stdio;
    alias PartialVec(T) = PartialVector!(T, 100);
    DynamicECS!(
        PartialVec,//Vector
        TypeSeqStruct!(int, double),
        TypeSeqStruct!(),
        TypeSeqStruct!(),
        TypeSeqStruct!(int),
        TypeSeqStruct!(),
    ) ecs;
    auto entity = ecs.add();
    entity.add!int(3);
    foreach (i; ecs.getComponents!int()) {
        writeln(i);
    }
    writeln("addUpdateList length: ", ecs.getAddUpdateList!int().length);
    entity.remove!int();
    writeln("addUpdateList length: ", ecs.getAddUpdateList!int().length);
    foreach (i; ecs.getComponents!int()) {
        writeln(i);
    }
}
