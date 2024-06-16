//
//  ViewModel+Audio.swift
//  Globes
//
//  Created by Bernhard Jenny on 14/6/2024.
//

import Foundation
import QuartzCore
import RealityKit

var debounce: [Entity: TimeInterval] = [:]
var lastCollisionTime = -TimeInterval.infinity

extension ViewModel {
    
    /// Don't play a collision sound if the last sound was played less than `debounceThreshold` seconds ago.
    private static let debounceThreshold = 0.2
    
    /// Loudness in decibel. 0 is maximum loudness, -infinity is silence.
    private static let relativeDecibels = -10.0
    
    /// Play a sound effect for a collision.
    /// - Parameters:
    ///   - collision: The collision.
    ///   - collisionAudioEntity: The entity that plays the sound. It will be moved to the location of the collision.
    func playAudio(for collision: CollisionEvents.Began, collisionAudioEntity: Entity) {
        Task { @MainActor in
            guard shouldHandleCollision,
                  let collisionSound = try? await collisionSoundResource() else { return }
                        
            // move the entity emitting the sound to the location of the collision
            collisionAudioEntity.position = collision.position
            
            let controller = collisionAudioEntity.playAudio(collisionSound)
            controller.gain = Self.relativeDecibels
        }
    }
    
    /// Load a collision sound to play.
    /// - Returns: An audio file to play.
    func collisionSoundResource() async throws -> AudioFileResource? {
        let collisionSoundName = UserDefaults.standard.string(forKey: "CollisionSound") ?? CollisionSound.defaultCollisionSound.rawValue
        guard let fileName = CollisionSound(rawValue: collisionSoundName)?.soundFileName else { return nil }
        return try await AudioFileResource(named: fileName)
    }
    
    /// If the last collision happened too recently, ignore the current collision.
    var shouldHandleCollision: Bool {
        let now = CACurrentMediaTime()
        if now - lastCollisionTime < Self.debounceThreshold {
            return false
        }
        lastCollisionTime = now
        return true
    }
}
